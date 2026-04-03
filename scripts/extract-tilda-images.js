#!/usr/bin/env node

/**
 * Extracts product image URLs from a Tilda product page.
 *
 * Tilda embeds product data as a JS object literal in a <script> tag:
 *   var product = { ... gallery: [{img: "..."}, ...], ... };
 *
 * The gallery array contains all product images in display order:
 *   [0] = main image, [1] = hover, [2..n] = additional.
 *
 * DOM <img> tags are NOT used — the product image is rendered via
 * background-image on a .js-product-img div, set at runtime by JS.
 * So we must parse the inline JSON instead.
 */

const https = require("https");
const http = require("http");
const cheerio = require("cheerio");

const url =
  process.argv[2] ||
  "https://tiffani.md/face/tproduct/712474259304-ottenochnii-plamper-dlya-gub-s-mikroigla";

function fetch(targetUrl) {
  return new Promise((resolve, reject) => {
    const client = targetUrl.startsWith("https") ? https : http;
    const headers = {
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.5",
    };
    client
      .get(targetUrl, { headers }, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return resolve(fetch(res.headers.location));
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

async function extractImages(pageUrl) {
  const html = await fetch(pageUrl);
  const $ = cheerio.load(html);

  // Strategy: find `var product = {...};` in <script> tags and parse the gallery array.
  // This is the only reliable source — Tilda does not put product images in <img> tags.
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
      // JSON parse may fail if Tilda uses JS-specific syntax.
      // Fallback: extract URLs from the gallery substring with regex.
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

  // Deduplicate while preserving order
  images = [...new Set(images)];

  return images;
}

(async () => {
  try {
    console.log(`Fetching: ${url}\n`);
    const images = await extractImages(url);

    if (images.length === 0) {
      console.log("No product images found.");
      process.exit(1);
    }

    console.log(`Found ${images.length} product image(s):\n`);
    images.forEach((img, i) => {
      const role = i === 0 ? "main" : i === 1 ? "hover" : `additional #${i}`;
      console.log(`  [${i}] (${role}) ${img}`);
    });

    console.log("\nJSON output:\n");
    console.log(JSON.stringify(images, null, 2));
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
})();
