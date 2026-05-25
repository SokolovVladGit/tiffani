import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export const MANUAL_IMPORT_SOURCE_TYPE = "yml_manual_import" as const;

export type ManualImportRunStatus =
  | "running"
  | "dry_run"
  | "dry_run_completed"
  | "completed"
  | "completed_with_errors"
  | "failed";

export interface RunMetadataSeed {
  source: string;
  dry_run: boolean;
  no_deactivation: true;
  admin_email?: string | null;
  filename?: string | null;
  file_size?: number;
  [key: string]: unknown;
}

export async function createManualImportRun(
  client: SupabaseClient,
  initialStatus: ManualImportRunStatus,
  metadata: RunMetadataSeed,
): Promise<string | null> {
  try {
    const { data, error } = await client
      .from("catalog_sync_runs")
      .insert({
        status: initialStatus,
        source_type: MANUAL_IMPORT_SOURCE_TYPE,
        started_at: new Date().toISOString(),
        metadata,
      })
      .select("id")
      .single();

    if (error || !data) {
      console.warn(
        "catalog-yml-import-manual: failed to create run row",
        error?.message,
      );
      return null;
    }
    return String(data.id);
  } catch (e) {
    console.warn(
      "catalog-yml-import-manual: unexpected error creating run row",
      e instanceof Error ? e.message : String(e),
    );
    return null;
  }
}

export interface FinalizeUpdate {
  status: ManualImportRunStatus;
  products_seen?: number;
  variants_seen?: number;
  images_seen?: number;
  products_upserted?: number;
  variants_upserted?: number;
  images_upserted?: number;
  error_count?: number;
  metadata?: Record<string, unknown>;
}

export async function finalizeManualImportRun(
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
        "catalog-yml-import-manual: failed to finalize run",
        error.message,
      );
    }
  } catch (e) {
    console.warn(
      "catalog-yml-import-manual: unexpected error finalizing run",
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

export async function persistManualImportErrors(
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
          `catalog-yml-import-manual: failed to persist errors (batch ${i})`,
          error.message,
        );
      }
    } catch (e) {
      console.warn(
        `catalog-yml-import-manual: unexpected error persisting errors (batch ${i})`,
        e instanceof Error ? e.message : String(e),
      );
    }
  }
}
