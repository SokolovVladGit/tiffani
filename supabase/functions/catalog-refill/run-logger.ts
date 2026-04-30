import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import type { BucketCounts } from "./types.ts";

export type RunStatus =
  | "running"
  | "dry_run"
  | "dry_run_completed"
  | "completed"
  | "completed_with_errors"
  | "failed";

export interface RunMetadataSeed {
  uid_list_size: number;
  dry_run: boolean;
  classifier_counts: BucketCounts;
  skipped_buckets: string[];
  [key: string]: unknown;
}

/**
 * Creates a `catalog_sync_runs` row for a refill invocation.
 * Returns the run id on success, or null on insert failure.
 * Failure is non-fatal by design — the refill itself must proceed.
 */
export async function createRefillRun(
  client: SupabaseClient,
  initialStatus: RunStatus,
  metadata: RunMetadataSeed,
): Promise<string | null> {
  const { data, error } = await client
    .from("catalog_sync_runs")
    .insert({
      status: initialStatus,
      source_type: "refill",
      started_at: new Date().toISOString(),
      metadata,
    })
    .select("id")
    .single();

  if (error || !data) {
    console.warn("catalog-refill: failed to create run row", error?.message);
    return null;
  }
  return String(data.id);
}

/**
 * Updates a `catalog_sync_runs` row with final counters + status.
 * Silent on failure — logging is best-effort.
 */
export async function finalizeRefillRun(
  client: SupabaseClient,
  runId: string | null,
  update: {
    status: RunStatus;
    products_seen?: number;
    variants_seen?: number;
    images_seen?: number;
    products_upserted?: number;
    variants_upserted?: number;
    images_upserted?: number;
    error_count?: number;
    metadata?: Record<string, unknown>;
  },
): Promise<void> {
  if (!runId) return;
  const { error } = await client
    .from("catalog_sync_runs")
    .update({
      ...update,
      finished_at: new Date().toISOString(),
    })
    .eq("id", runId);
  if (error) {
    console.warn("catalog-refill: failed to finalize run", error.message);
  }
}

export async function persistRefillErrors(
  client: SupabaseClient,
  runId: string | null,
  errors: Array<{
    stage: string;
    external_key: string;
    message: string;
    details?: Record<string, unknown>;
  }>,
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
    const { error } = await client
      .from("catalog_sync_run_errors")
      .insert(rows.slice(i, i + BATCH));
    if (error) {
      console.warn(
        `catalog-refill: failed to persist errors (batch ${i})`,
        error.message,
      );
    }
  }
}
