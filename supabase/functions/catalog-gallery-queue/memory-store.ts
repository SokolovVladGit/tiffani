import {
  claimBatch,
  iso,
  leaseOpen,
  type CatalogCandidate,
  type QueueItem,
  type QueueRun,
} from "./model.ts";

export interface QueueStore {
  now(): number;
  loadCandidates(): Promise<CatalogCandidate[]>;
  loadItems(): Promise<QueueItem[]>;
  /** Authoritative row count, independent of a paged read. */
  countItems(): Promise<number>;
  saveItems(items: QueueItem[]): Promise<void>;
  /** Writes only while this worker still holds claim_token. Returns saved UIDs. */
  saveOwned(items: QueueItem[], token: string): Promise<string[]>;
  /** Writes only rows whose lease is open, so a holder is not overwritten. */
  saveIfLeaseOpen(items: QueueItem[]): Promise<string[]>;
  claim(limit: number, token: string): Promise<QueueItem[]>;
  /** Claims every UID or none. Null means another worker holds one of them. */
  claimLive(uids: string[], token: string): Promise<QueueItem[] | null>;
  claimForRecheck(uid: string, token: string): Promise<
    { item: QueueItem } | { error: "missing" | "claim_held" }
  >;
  addRun(run: QueueRun): Promise<void>;
  finishRun(
    id: string,
    patch: Pick<QueueRun, "status" | "result" | "errorCount" | "writes" | "finishedAt">,
  ): Promise<void>;
  abandonRunsStartedBefore(cutoffMs: number): Promise<void>;
  listRuns(limit: number): Promise<QueueRun[]>;
}

export class MemoryQueueStore implements QueueStore {
  candidates: CatalogCandidate[] = [];
  items: QueueItem[] = [];
  runs: QueueRun[] = [];
  nowMs = Date.parse("2026-11-14T14:00:00.000Z");
  private tail: Promise<unknown> = Promise.resolve();

  now(): number {
    return this.nowMs;
  }

  loadCandidates(): Promise<CatalogCandidate[]> {
    return Promise.resolve(this.candidates.map((candidate) => ({ ...candidate, galleryUrls: [...candidate.galleryUrls] })));
  }

  loadItems(): Promise<QueueItem[]> {
    return Promise.resolve(this.items.map((item) => ({ ...item, importableUrls: [...item.importableUrls] })));
  }

  countItems(): Promise<number> {
    return Promise.resolve(this.items.length);
  }

  saveItems(items: QueueItem[]): Promise<void> {
    return this.exclusive(() => {
      this.writeItems(items, () => true, true);
    });
  }

  saveOwned(items: QueueItem[], token: string): Promise<string[]> {
    return this.exclusive(() =>
      this.writeItems(items, (current) => current.claimToken === token, false)
    );
  }

  saveIfLeaseOpen(items: QueueItem[]): Promise<string[]> {
    return this.exclusive(() =>
      this.writeItems(items, (current) => leaseOpen(current, this.nowMs), false)
    );
  }

  claim(limit: number, token: string): Promise<QueueItem[]> {
    return this.exclusive(() => {
      const result = claimBatch(this.items, this.nowMs, limit, token);
      this.items = result.items;
      return result.claimed.map((item) => ({ ...item, importableUrls: [...item.importableUrls] }));
    });
  }

  claimLive(uids: string[], token: string): Promise<QueueItem[] | null> {
    return this.exclusive(() => {
      if (uids.length === 0 || uids.length > 20 || token.length < 8 || new Set(uids).size !== uids.length) {
        return null;
      }
      const rows = uids.map((uid) => this.items.find((item) => item.tildaUid === uid));
      if (rows.some((row) => !row || row.status !== "ready_for_review" || !leaseOpen(row, this.nowMs))) {
        return null;
      }
      const claimedAt = iso(this.nowMs);
      for (const row of rows) {
        const index = this.items.findIndex((item) => item.productId === row!.productId);
        this.items[index] = {
          ...this.items[index],
          claimedAt,
          claimToken: token,
          updatedAt: claimedAt,
        };
      }
      return rows.map((row) => this.copy(this.items.find((item) => item.productId === row!.productId)!));
    });
  }

  claimForRecheck(uid: string, token: string): Promise<
    { item: QueueItem } | { error: "missing" | "claim_held" }
  > {
    return this.exclusive(() => {
      const index = this.items.findIndex((item) => item.tildaUid === uid);
      if (index < 0) return { error: "missing" as const };
      if (!leaseOpen(this.items[index], this.nowMs)) return { error: "claim_held" as const };
      const claimedAt = iso(this.nowMs);
      this.items[index] = {
        ...this.items[index],
        status: "pending",
        nextCheckAt: null,
        claimedAt,
        claimToken: token,
        updatedAt: claimedAt,
      };
      return { item: this.copy(this.items[index]) };
    });
  }

  addRun(run: QueueRun): Promise<void> {
    this.runs.push(run);
    return Promise.resolve();
  }

  finishRun(
    id: string,
    patch: Pick<QueueRun, "status" | "result" | "errorCount" | "writes" | "finishedAt">,
  ): Promise<void> {
    const run = this.runs.find((row) => row.id === id);
    if (!run || run.status !== "running") return Promise.resolve();
    run.status = patch.status;
    run.result = patch.result;
    run.errorCount = patch.errorCount;
    run.writes = patch.writes;
    run.finishedAt = patch.finishedAt;
    return Promise.resolve();
  }

  abandonRunsStartedBefore(cutoffMs: number): Promise<void> {
    const finishedAt = iso(this.nowMs);
    for (const run of this.runs) {
      if (run.status !== "running" || Date.parse(run.startedAt) > cutoffMs) continue;
      run.status = "abandoned";
      run.finishedAt = finishedAt;
      run.result = { ...run.result, abandoned: "lease_expired" };
    }
    return Promise.resolve();
  }

  listRuns(limit: number): Promise<QueueRun[]> {
    return Promise.resolve(this.runs.slice(-limit).reverse());
  }

  private exclusive<T>(fn: () => T): Promise<T> {
    const run = this.tail.then(() => fn());
    this.tail = run.then(() => undefined, () => undefined);
    return run;
  }

  private copy(item: QueueItem): QueueItem {
    return { ...item, importableUrls: [...item.importableUrls] };
  }

  private writeItems(
    items: QueueItem[],
    allow: (current: QueueItem) => boolean,
    insert: boolean,
  ): string[] {
    const saved: string[] = [];
    for (const item of items) {
      const clash = this.items.find((row) =>
        row.tildaUid === item.tildaUid && row.productId !== item.productId
      );
      if (clash) throw new Error("duplicate_tilda_uid");
      const index = this.items.findIndex((row) => row.productId === item.productId);
      if (index < 0) {
        if (!insert) continue;
        this.items.push(this.copy(item));
        saved.push(item.tildaUid);
        continue;
      }
      if (!allow(this.items[index]) || this.items[index].tildaUid !== item.tildaUid) continue;
      this.items[index] = this.copy(item);
      saved.push(item.tildaUid);
    }
    return saved;
  }
}
