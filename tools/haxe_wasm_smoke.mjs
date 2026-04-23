/**
 * One-off: run Vite on 4444 (assumed already up), load Haxe wasm example, print console + page errors.
 * Usage: node tools/haxe_wasm_smoke.mjs
 */
import puppeteer from "puppeteer-core";

const url = process.env.SMOKE_URL || "https://127.0.0.1:4444/?example=haxe";
const exec = process.env.CHROMIUM || "/usr/bin/chromium-browser";
const settleMs = Number(process.env.SMOKE_SETTLE_MS || "12000");

const browser = await puppeteer.launch({
  executablePath: exec,
  headless: true,
  args: [
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--ignore-certificate-errors",
    "--allow-insecure-localhost",
  ],
});

const page = await browser.newPage();
page.on("console", (msg) => {
  const t = msg.type();
  const text = msg.text();
  console.log(`[console.${t}] ${text}`);
});
page.on("pageerror", (err) => {
  console.log(`[pageerror] ${err?.message || err}`);
});
page.on("requestfailed", (req) => {
  console.log(`[requestfailed] ${req.url()} ${req.failure()?.errorText || ""}`);
});

try {
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
} catch (e) {
  console.log(`[goto] ${e?.message || e}`);
}
await new Promise((r) => setTimeout(r, settleMs));
await browser.close();
