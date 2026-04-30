import type { RefillConfig } from "./config.ts";
import type { BucketCounts, UidBucket, UidClassification } from "./types.ts";
import { lookupUid, type YmlIndex } from "./yml-index.ts";
import { probeTproduct, type ProbeResult } from "./tproduct-probe.ts";

export interface ClassifierDeps {
  /**
   * Optional probe override, used by tests. Production path uses
   * the real HTTP probe against /tproduct/<uid>.
   */
  probe?: (uid: string) => Promise<ProbeResult>;
}

const UID_REGEX = /^\d{6,20}$/;

export async function classifyUids(
  rawUids: readonly string[],
  index: YmlIndex,
  config: RefillConfig,
  deps: ClassifierDeps = {},
): Promise<UidClassification[]> {
  const probe = deps.probe ?? ((u: string) => probeTproduct(u, config));

  const normalized = rawUids.map((u) => String(u ?? "").trim());
  const order = new Map<string, number>();
  normalized.forEach((u, i) => {
    if (!order.has(u)) order.set(u, i);
  });

  const out = new Map<string, UidClassification>();
  const probeQueue: string[] = [];

  for (const uid of normalized) {
    if (out.has(uid)) continue;

    if (!UID_REGEX.test(uid)) {
      out.set(uid, { uid, bucket: "invalid_uid" });
      continue;
    }

    const { offer, groupOffers } = lookupUid(index, uid);
    if (offer) {
      out.set(uid, {
        uid,
        bucket: "found_in_yml_offer",
        offer_id: offer.id,
        group_id: offer.groupId,
      });
      continue;
    }
    if (groupOffers && groupOffers.length > 0) {
      out.set(uid, {
        uid,
        bucket: "found_in_yml_group",
        group_id: uid,
        variants_count: groupOffers.length,
      });
      continue;
    }
    probeQueue.push(uid);
  }

  await runProbes(probeQueue, config, probe, out);

  return normalized
    .filter((u, i) => order.get(u) === i)
    .map((u) => out.get(u)!)
    .filter(Boolean);
}

async function runProbes(
  queue: readonly string[],
  config: RefillConfig,
  probe: (uid: string) => Promise<ProbeResult>,
  out: Map<string, UidClassification>,
): Promise<void> {
  if (queue.length === 0) return;

  const concurrency = Math.max(1, Math.min(config.probeConcurrency, queue.length));
  let cursor = 0;

  async function worker(): Promise<void> {
    while (cursor < queue.length) {
      const i = cursor++;
      const uid = queue[i];
      let res: ProbeResult;
      try {
        res = await probe(uid);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        res = { status: "fetch_error", message: msg };
      }
      out.set(uid, toClassification(uid, res));
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));
}

function toClassification(uid: string, r: ProbeResult): UidClassification {
  let bucket: UidBucket;
  if (r.status === "ok") bucket = "needs_manual_review";
  else if (r.status === "not_found") bucket = "tilda_gone";
  else bucket = "probe_error";

  return {
    uid,
    bucket,
    probe: {
      status: r.status,
      http_status: r.http_status,
      message: r.message,
      parent_uid: r.product?.parentuid,
      title_len: typeof r.product?.title === "string"
        ? r.product.title.length
        : undefined,
    },
  };
}

export interface Summary {
  counts: BucketCounts;
  samples: Partial<Record<UidBucket, UidClassification[]>>;
}

const ALL_BUCKETS: UidBucket[] = [
  "found_in_yml_offer",
  "found_in_yml_group",
  "needs_manual_review",
  "tilda_gone",
  "probe_error",
  "invalid_uid",
];

export function summarize(
  results: readonly UidClassification[],
  sampleLimit: number,
): Summary {
  const counts: BucketCounts = {
    found_in_yml_offer: 0,
    found_in_yml_group: 0,
    needs_manual_review: 0,
    tilda_gone: 0,
    probe_error: 0,
    invalid_uid: 0,
  };
  const samples: Partial<Record<UidBucket, UidClassification[]>> = {};
  for (const b of ALL_BUCKETS) samples[b] = [];

  for (const r of results) {
    counts[r.bucket] += 1;
    const arr = samples[r.bucket]!;
    if (arr.length < sampleLimit) arr.push(r);
  }

  for (const b of ALL_BUCKETS) {
    if (samples[b]!.length === 0) delete samples[b];
  }

  return { counts, samples };
}
