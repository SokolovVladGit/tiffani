# Supabase Edge Functions — Deployment Notes

This directory contains the project's Supabase Edge Functions. Each subdirectory
(`order-notify`, `consultation-notify`, `catalog-sync`, ...) holds one function
implementation as a Deno entry point at `index.ts`.

The notes below capture the **operational requirements** that are easy to miss
on a fresh deploy and have caused regressions in the past. They do **not**
describe runtime behavior — see each function's own source for that.

---

## JWT verification mode (must match the function's caller)

Supabase Edge Functions are gated by JWT verification by default: every request
must carry a valid Supabase auth token in the `Authorization` header. That works
for server-to-server callers (the dashboard, cron jobs, other functions), but
**fails for fire-and-forget calls dispatched by the mobile client** in the
following situations:

- the user is not signed in (anonymous CTA submission), or
- the client deliberately treats the call as fire-and-forget and does not
  attach a fresh session token.

In those cases the function returns **`401 Invalid JWT`** before the function
body ever runs. The DB write that preceded the call still succeeds (it does not
go through the function), but the side-effect the function was supposed to
perform — sending a Telegram notification, in our case — is silently skipped.

Both notification functions in this project must therefore be deployed with
JWT verification disabled. The repo pins this at two layers so it cannot
regress on a fresh deploy:

### 1. Pinned in `supabase/config.toml`

```toml
[functions.order-notify]
verify_jwt = false

[functions.consultation-notify]
verify_jwt = false
```

`supabase functions deploy <name>` reads this file and applies the setting
automatically. **Always deploy from the repo root**, not from inside the
function folder, so the CLI picks up `supabase/config.toml`.

### 2. Equivalent CLI flag (use only as a fallback)

If for any reason you bypass the project config (one-off deploy from another
machine, CI job that does not check out the full repo, etc.), pass the flag
explicitly:

```bash
supabase functions deploy order-notify          --project-ref <ref> --no-verify-jwt
supabase functions deploy consultation-notify   --project-ref <ref> --no-verify-jwt
```

The two mechanisms are equivalent. The `config.toml` entry is preferred
because it is version-controlled and applies on every subsequent deploy
without anyone having to remember the flag.

---

## Required function secrets

Both notification functions read four environment variables (see each
`index.ts` for the read site):

| Secret                        | Provided by              | Notes |
|-------------------------------|--------------------------|-------|
| `SUPABASE_URL`                | Supabase platform        | Auto-set on every Edge Function. |
| `SUPABASE_SERVICE_ROLE_KEY`   | Supabase platform        | Auto-set; gives the function row-level access for read-back. |
| `TELEGRAM_BOT_TOKEN`          | Operator (`secrets set`) | Shared by `order-notify` and `consultation-notify`. |
| `TELEGRAM_CHAT_ID`            | Operator (`secrets set`) | Shared by `order-notify` and `consultation-notify`. |

```bash
supabase secrets set TELEGRAM_BOT_TOKEN=...     --project-ref <ref>
supabase secrets set TELEGRAM_CHAT_ID=...       --project-ref <ref>
supabase secrets list                            --project-ref <ref>
```

---

## Per-function status

### `order-notify`
- Triggered fire-and-forget by `CartRemoteDataSourceImpl._notifyOrder` after a
  successful `submit_order_v2` RPC.
- Reads the order row + items from `order_requests` / `order_request_items`
  using the service role key (DB is authoritative for the message body).
- Sends a Telegram message; failure is logged client-side at warn level only,
  never blocks the order.
- **Must be deployed with `verify_jwt = false`** (already pinned in
  `config.toml`).

### `consultation-notify`
- Triggered fire-and-forget by `ConsultationRemoteDataSourceImpl._notifyConsultation`
  after a successful `submit_consultation_v1` RPC.
- Reads the row from `consultation_requests` using the service role key.
- Sends a Telegram message; failure is logged client-side at warn level only,
  never blocks the consultation submission.
- **Must be deployed with `verify_jwt = false`** (now pinned in `config.toml`).
- *Operational consequence if this is missed:* every consultation submit will
  succeed at the DB layer (row is created in `consultation_requests`), but the
  manager's Telegram chat will receive **nothing**, and the dev console will
  show `consultation-notify failed (non-blocking): ... 401 Invalid JWT`. The
  user-facing flow is unaffected (the success SnackBar still appears) — only
  the manager notification is lost. **This does not affect `order-notify` or
  any part of the order flow.**

### `catalog-sync`
- Server-driven (cron / dashboard / pg_net), not invoked from the mobile
  client. JWT verification mode is whatever Supabase defaults to and is
  intentionally not pinned.

---

## End-to-end verification after a deploy

After `supabase functions deploy consultation-notify` (or `order-notify`):

1. **From the mobile app**, submit a consultation request via the Info screen
   CTA block (or place a test order via checkout).
2. **In the Supabase SQL Editor**, confirm the row exists:
   ```sql
   SELECT id, customer_name, phone, source, status, created_at
   FROM public.consultation_requests
   ORDER BY created_at DESC LIMIT 5;
   ```
   (For the order flow: `SELECT … FROM public.order_requests ORDER BY created_at DESC LIMIT 5;`.)
3. **Check the manager's Telegram chat** — a new message of the form
   `💬 Новая заявка на консультацию #<8-char id>` (consultation) or
   `🛒 Новый заказ #<8-char id>` (order) should arrive within a few seconds.
4. **In the function's runtime logs** (`supabase functions logs <name>` or the
   dashboard), confirm there are no `401 Invalid JWT` entries for invocations
   triggered by the app. Their presence means JWT verification is still on for
   that function and the deploy needs to be re-run with the flag / config above.
