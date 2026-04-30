import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Lifecycle helpers for `catalog_sync_runs` rows produced by
 * the safe YML sync. All rows are stamped with
 * `source_type = 'yml_safe_sync'` so monitoring queries can
 * separate this path from `catalog-sync` and `catalog-refill`.
 *
 * Logging is best-effort: a failed insert/update never aborts
 * the sync. We still surface warnings via `console.warn` so they
 * appear in function logs.
 */

export const SAFE_SYNC_SOURCE_TYPE = "yml_safe_sync" as const;

export type SafeSyncRunStatus =
  | "running"
  | "dry_run"
  | "dry_run_completed"
  | "completed"
  | "completed_with_errors"
  | "failed";

export interface RunMetadataSeed {
  source: string;
  dry_run: boolean;
  /**
   * Compile-time invariant pinned in the run metadata so any
   * monitoring tool can confirm the safety contract per-run.
   */
  no_deactivation: true;
  [key: string]: unknown;
}

/**
 * Inserts a fresh `catalog_sync_runs` row and returns its id.
 * Returns `null` when the insert fails so callers can continue
 * the run without a database-side run id (best-effort logging).
 */
export async function createSafeSyncRun(
  client: SupabaseClient,
  initialStatus: SafeSyncRunStatus,
  metadata: RunMetadataSeed,
): Promise<string | null> {
  try {
    const { data, error } = await client
      .from("catalog_sync_runs")
      .insert({
        status: initialStatus,
        source_type: SAFE_SYNC_SOURCE_TYPE,
        started_at: new Date().toISOString(),
        metadata,
      })
      .select("id")
      .single();

    if (error || !data) {
      console.warn(
        "catalog-yml-sync-safe: failed to create run row",
        error?.message,
      );
      return null;
    }
    return String(data.id);
  } catch (e) {
    console.warn(
      "catalog-yml-sync-safe: unexpected error creating run row",
      e instanceof Error ? e.message : String(e),
    );
    return null;
  }
}

export interface FinalizeUpdate {
  status: SafeSyncRunStatus;
  products_seen?: number;
  variants_seen?: number;
  images_seen?: number;
  products_upserted?: number;
  variants_upserted?: number;
  images_upserted?: number;
  error_count?: number;
  metadata?: Record<string, unknown>;
}

/**
 * Updates an existing `catalog_sync_runs` row with final counters
 * and status. Silent on no-op when `runId` is null. Errors are
 * logged but never thrown — finalization is best-effort.
 */
export async function finalizeSafeSyncRun(
  client: SupabaseClient,
  runId: string | null,
  update: FinalizeUpdate,
): Promise<void> {
  if (!runId) return;
  try {
    const { error } = await client
      .from("catalog_sync_runs")
      .update({ ...update, finished_at: new Date().toISOString() })
      .eq("id", runId);
    if (error) {
      console.warn(
        "catalog-yml-sync-safe: failed to finalize run",
        error.message,
      );
    }
  } catch (e) {
    console.warn(
      "catalog-yml-sync-safe: unexpected error finalizing run",
      e instanceof Error ? e.message : String(e),
    );
  }
}

export interface RunErrorRow {
  stage: string;
  external_key: string;
  message: string;
  details?: Record<string, unknown>;
}

/**
 * Persists per-row errors for the given run id in batches of 100.
 * No-op when there are no errors or no run id. Insert failures are
 * warned but never thrown — we never want logging to mask the
 * actual sync outcome.
 */
export async function persistSafeSyncErrors(
  client: SupabaseClient,
  runId: string | null,
  errors: RunErrorRow[],
): Promise<void> {
  if (!runId || errors.length === 0) return;
  const rows = errors.map((e) => ({
    run_id: runId,
    stage: e.stage,
    external_key: e.external_key,
    message: e.message,
    details: e.details ?? null,
  }));

  const BATCH = 100;
  for (let i = 0; i < rows.length; i += BATCH) {
    try {
      const { error } = await client
        .from("catalog_sync_run_errors")
        .insert(rows.slice(i, i + BATCH));
      if (error) {
        console.warn(
          `catalog-yml-sync-safe: failed to persist errors (batch ${i})`,
          error.message,
        );
      }
    } catch (e) {
      console.warn(
        `catalog-yml-sync-safe: unexpected error persisting errors (batch ${i})`,
        e instanceof Error ? e.message : String(e),
      );
    }
  }
}
