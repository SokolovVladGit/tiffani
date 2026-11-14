import {
  decideSafeSyncAuth,
  type SafeSyncAuthResult,
  type UserLookup,
} from "../catalog-yml-sync-safe/auth.ts";

/**
 * Gallery recovery uses the YML sync admin decision and ignores any
 * caller-supplied role, cron source, or admin flag. The body is not an input.
 */
export function decideGalleryAuth(input: {
  bearer: string | null;
  serviceRoleKey: string | null;
  lookup: UserLookup | null;
  serviceJwt?: boolean;
}): SafeSyncAuthResult {
  return decideSafeSyncAuth({
    bearer: input.bearer,
    serviceRoleKey: input.serviceRoleKey,
    lookup: input.lookup,
    serviceJwt: input.serviceJwt,
    source: "manual",
  });
}
