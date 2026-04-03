#!/usr/bin/env node

/**
 * Batch-extracts product images from Tilda product pages.
 *
 * Input:  CSV with a "Tilda UID" column.
 * Output: product_images.csv with columns: product_tilda_uid, url, position
 *
 * Each UID is turned into https://tiffani.md/tproduct/{UID} — no slug needed,
 * Tilda redirects UID-only URLs to the canonical product page.
 *
 * Images come from `var product = {...}` embedded in <script> tags;
 * the gallery array [{img: "..."}, ...] is the source of truth.
 */

const fs = require("fs");
const path = require("path");
const https = require("https");
const http = require("http");
const cheerio = require("cheerio");

const CONCURRENCY = 5;
const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 1000;

const INPUT_FILE = process.argv[2];
const OUTPUT_FILE = process.argv[3] || "product_images.csv";

if (!INPUT_FILE) {
  console.error("Usage: node extract-tilda-images-batch.js <input.csv> [output.csv]");
  process.exit(1);
}

// --- HTTP ---

const REQUEST_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Language": "en-US,en;q=0.5",
};

function fetchHtml(targetUrl) {
  return new Promise((resolve, reject) => {
    const client = targetUrl.startsWith("https") ? https : http;
    client
      .get(targetUrl, { headers: REQUEST_HEADERS }, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return resolve(fetchHtml(res.headers.location));
        }
        if (res.statusCode !== 200) {
          return reject(new Error(`HTTP ${res.statusCode}`));
        }
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => resolve(Buffer.concat(chunks).toString()));
        res.on("error", reject);
      })
      .on("error", reject);
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// --- Image extraction (same logic as single-page script) ---

function parseImagesFromHtml(html) {
  const $ = cheerio.load(html);
  let images = [];

  $("script").each((_, el) => {
    const content = $(el).html() || "";
    const match = content.match(/var\s+product\s*=\s*(\{.+?\});/s);
    if (!match) return;

    try {
      const product = JSON.parse(match[1]);
      if (Array.isArray(product.gallery)) {
        for (const entry of product.gallery) {
          if (entry.img && entry.img.includes("static.tildacdn.com")) {
            images.push(entry.img);
          }
        }
      }
    } catch {
      const galleryMatch = match[1].match(/"gallery"\s*:\s*\[([^\]]+)\]/);
      if (galleryMatch) {
        const urlMatches = galleryMatch[1].match(
          /https?:\\?\/\\?\/static\.tildacdn\.com[^"'\\]+/g
        );
        if (urlMatches) {
          images = urlMatches.map((u) => u.replace(/\\\//g, "/"));
        }
      }
    }
  });

  return [...new Set(images)].filter((u) => u.includes("static.tildacdn.com"));
}

// --- Fetch with retry ---

async function fetchProductImages(uid) {
  const url = `https://tiffani.md/tproduct/${uid}`;
  let lastError;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      if (attempt > 0) await sleep(RETRY_DELAY_MS * attempt);
      const html = await fetchHtml(url);
      return parseImagesFromHtml(html);
    } catch (err) {
      lastError = err;
    }
  }

  throw lastError;
}

// --- CSV read/write ---

function readCsv(filePath) {
  const raw = fs.readFileSync(path.resolve(filePath), "utf-8");
  const lines = raw.split(/\r?\n/).filter((l) => l.trim());
  if (lines.length < 2) throw new Error("CSV has no data rows");

  const headerLine = lines[0];
  const headers = parseCsvLine(headerLine);

  const uidIndex = headers.findIndex(
    (h) => h.trim().toLowerCase().replace(/[^a-z0-9]/g, "") === "tildauid"
  );
  if (uidIndex === -1) {
    throw new Error(
      `Column "Tilda UID" not found. Available: ${headers.join(", ")}`
    );
  }

  const photoIndex = headers.findIndex(
    (h) => h.trim().toLowerCase() === "photo"
  );

  const products = [];
  for (let i = 1; i < lines.length; i++) {
    const cols = parseCsvLine(lines[i]);
    const uid = (cols[uidIndex] || "").trim();
    const photo = photoIndex !== -1 ? (cols[photoIndex] || "").trim() : "";
    if (uid) products.push({ uid, photo });
  }

  return products;
}

function parseCsvLine(line) {
  const cols = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === "," && !inQuotes) {
      cols.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  cols.push(current);
  return cols;
}

function writeCsv(filePath, rows) {
  const header = "product_tilda_uid,url,position\n";
  const body = rows
    .map((r) => `${r.product_tilda_uid},${r.url},${r.position}`)
    .join("\n");
  fs.writeFileSync(path.resolve(filePath), header + body + "\n", "utf-8");
}

// --- Concurrency-limited processing ---

async function processAll(products) {
  const results = [];
  const failed = [];
  let completed = 0;
  const total = products.length;

  async function worker(queue) {
    while (queue.length > 0) {
      const { uid, photo } = queue.shift();
      try {
        const images = await fetchProductImages(uid);
        if (images.length > 0) {
          for (let i = 0; i < images.length; i++) {
            results.push({ product_tilda_uid: uid, url: images[i], position: i });
          }
        } else if (photo) {
          console.warn(`  ⚠ ${uid} → fallback to main photo`);
          results.push({ product_tilda_uid: uid, url: photo, position: 0 });
        } else {
          console.warn(`  ⚠ ${uid}: no gallery and no photo, skipping`);
          failed.push({ uid, reason: "no gallery, no photo" });
        }
      } catch (err) {
        if (photo) {
          console.warn(`  ⚠ ${uid} → fetch failed, fallback to main photo`);
          results.push({ product_tilda_uid: uid, url: photo, position: 0 });
        } else {
          console.error(`  ✗ ${uid}: ${err.message}`);
          failed.push({ uid, reason: err.message });
        }
      }

      completed++;
      if (completed % 5 === 0 || completed === total) {
        console.log(`  Processed ${completed} / ${total}`);
      }
    }
  }

  const queue = [...products];
  const workers = Array.from({ length: Math.min(CONCURRENCY, products.length) }, () =>
    worker(queue)
  );
  await Promise.all(workers);

  return { results, failed };
}

// --- Main ---

(async () => {
  try {
    console.log(`Reading: ${INPUT_FILE}`);
    const products = readCsv(INPUT_FILE);
    console.log(`Found ${products.length} product(s)\n`);

    if (products.length === 0) {
      console.log("No products to process.");
      process.exit(0);
    }

    console.log(`Fetching images (concurrency: ${CONCURRENCY})...\n`);
    const { results, failed } = await processAll(products);

    writeCsv(OUTPUT_FILE, results);
    console.log(`\nWrote ${results.length} image row(s) to ${OUTPUT_FILE}`);

    if (failed.length > 0) {
      const failedPath = path.resolve(path.dirname(OUTPUT_FILE), "failed_uids.txt");
      fs.writeFileSync(failedPath, failed.map((f) => f.uid).join("\n") + "\n", "utf-8");
      console.log(`\nFailed UIDs (${failed.length}) written to ${failedPath}:`);
      for (const f of failed) {
        console.log(`  ${f.uid} — ${f.reason}`);
      }
    }
  } catch (err) {
    console.error(`Fatal: ${err.message}`);
    process.exit(1);
  }
})();
