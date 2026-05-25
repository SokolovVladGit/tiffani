# Audit helpers (read-only)

## `inspect-tilda-yml-offer.ts`

Fetches the Tilda YML export via `TILDA_YML_URL` (GET only). Use before/after toggling product visibility in Tilda.

Requires: Deno 1.x+.

```bash
export TILDA_YML_URL="https://your-feed-url"
deno run --allow-net --allow-env scripts/audit/inspect-tilda-yml-offer.ts --offer=184192311111
```

Options (repeat `--offer` for several UIDs):

- `--offer=<variant/offer UID>`
- `--group=<group_id>` (optional filter)
- `--title=<substring>` (optional case-insensitive match on `<name>`)

Output is JSON: per-offer `available_flag`, `xml_attributes_on_offer`, picture counts, category, and `present_in_yml: false` stubs for requested offer IDs not found.

No database credentials or Tilda API keys are used.
