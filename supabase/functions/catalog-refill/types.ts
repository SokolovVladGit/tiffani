export type UidBucket =
  | "found_in_yml_offer"
  | "found_in_yml_group"
  | "needs_manual_review"
  | "tilda_gone"
  | "probe_error"
  | "invalid_uid";

export interface ProbeSummary {
  status: "ok" | "not_found" | "fetch_error" | "parse_error";
  http_status?: number;
  message?: string;
  parent_uid?: string;
  title_len?: number;
}

export interface UidClassification {
  uid: string;
  bucket: UidBucket;
  offer_id?: string;
  group_id?: string;
  variants_count?: number;
  probe?: ProbeSummary;
}

export interface BucketCounts {
  found_in_yml_offer: number;
  found_in_yml_group: number;
  needs_manual_review: number;
  tilda_gone: number;
  probe_error: number;
  invalid_uid: number;
}

export interface ClassificationSummary {
  total: number;
  counts: BucketCounts;
  samples: Partial<Record<UidBucket, UidClassification[]>>;
  yml_meta: {
    offers_count: number;
    groups_count: number;
    categories_count: number;
  };
  dry_run: true;
  generated_at: string;
  notes?: string[];
}
