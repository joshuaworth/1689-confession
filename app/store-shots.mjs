import { chromium } from 'playwright';
import fs from 'fs';

const OUT = 'store-screens';
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 440, height: 956 },   // 6.9" logical points
  deviceScaleFactor: 3,                     // -> 1320 x 2868 PNGs
  isMobile: true,
  hasTouch: true,
  userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
});
await ctx.addInitScript(() => {
  localStorage.setItem('bm', JSON.stringify(['c1p1', 'c11p1', 'c17p1']));
  localStorage.setItem('nt', JSON.stringify({
    c11p1: 'Justification is by faith alone, but not by a faith that is alone. See paragraph 2.',
  }));
  localStorage.setItem('theme', 'light');
});
const page = await ctx.newPage();
await page.goto('https://1689.intentmesh.dev/', { waitUntil: 'networkidle' });
await page.waitForTimeout(1200);

// 1. Hero
await page.screenshot({ path: `${OUT}/01-hero.png` });

// 2. Scripture proof open, in place
await page.evaluate(() => document.getElementById('c1p1').scrollIntoView());
await page.waitForTimeout(300);
await page.evaluate(() => window.scrollBy(0, -80));
await page.waitForTimeout(200);
await page.evaluate(() => document.querySelector('#c1p1 .proofs .ref').click());
await page.waitForTimeout(900);
await page.screenshot({ path: `${OUT}/02-proof.png` });

// 3. Search
await page.evaluate(() => document.getElementById('tbSearch').click());
await page.waitForTimeout(300);
await page.type('#searchInput', 'effectual calling', { delay: 30 });
await page.waitForTimeout(900);
await page.screenshot({ path: `${OUT}/03-search.png` });
await page.evaluate(() => document.getElementById('searchEsc').click());
await page.waitForTimeout(300);

// 4. Note in the text flow
await page.evaluate(() => document.getElementById('c11p1').scrollIntoView());
await page.waitForTimeout(250);
await page.evaluate(() => window.scrollBy(0, -90));
await page.waitForTimeout(300);
await page.screenshot({ path: `${OUT}/04-note.png` });

// 5. Contents sheet with bookmarks
await page.evaluate(() => document.getElementById('tbContents').click());
await page.waitForTimeout(500);
await page.screenshot({ path: `${OUT}/05-bookmarks.png` });
await page.evaluate(() => document.getElementById('sideClose').click());
await page.waitForTimeout(300);

// 6. Candlelight (dark) with proof open
await page.evaluate(() => document.getElementById('tbTheme').click());
await page.waitForTimeout(400);
await page.evaluate(() => document.getElementById('c1p1').scrollIntoView());
await page.evaluate(() => window.scrollBy(0, -80));
await page.waitForTimeout(400);
await page.screenshot({ path: `${OUT}/06-dark.png` });

await browser.close();
console.log('done', fs.readdirSync(OUT));
