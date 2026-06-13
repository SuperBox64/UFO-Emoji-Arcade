// Visual capture via Playwright (driving system Chrome). Loads the served
// build, waits for the canvas to actually paint, screenshots the title, then
// presses Space + flies/fires and screenshots live gameplay.
//
//   node tools/shoot.mjs <baseUrl>
import { createRequire } from 'node:module';
const require = createRequire('/opt/homebrew/lib/node_modules/@playwright/mcp/node_modules/');
const { chromium } = require('playwright-core');

const BASE = process.argv[2] || 'http://localhost:8754';
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const browser = await chromium.launch({
  headless: true,
  executablePath: CHROME,
  args: ['--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', (m) => { const t = m.text(); if (/error|fail|trap|exception/i.test(t)) console.log('  [page]', t); });
page.on('pageerror', (e) => console.log('  [pageerror]', e.message));

await page.goto(`${BASE}/index.html`, { waitUntil: 'load' });

// Wait until the canvas has painted something non-black (real frames running).
async function canvasIsLive() {
  return await page.evaluate(() => {
    const c = document.getElementById('game');
    if (!c) return false;
    const t = document.createElement('canvas');
    t.width = 64; t.height = 36;
    const g = t.getContext('2d');
    try { g.drawImage(c, 0, 0, t.width, t.height); } catch (_e) { return false; }
    const d = g.getImageData(0, 0, t.width, t.height).data;
    let lit = 0;
    for (let i = 0; i < d.length; i += 4) if (d[i] + d[i+1] + d[i+2] > 40) lit++;
    return lit > 20; // enough non-black pixels => something rendered
  });
}

let live = false;
for (let i = 0; i < 40; i++) {
  if (await canvasIsLive()) { live = true; break; }
  await page.waitForTimeout(250);
}
console.log(live ? '✓ canvas painted (title screen rendering)' : '✗ canvas still blank after 10s');
await page.screenshot({ path: '/tmp/ufo_title.png' });

// Start the game and play a little.
await page.keyboard.press('Space');
await page.waitForTimeout(2600);            // ready · set · go
await page.keyboard.down('ArrowUp');
await page.keyboard.down('Space');
await page.waitForTimeout(900);
await page.keyboard.up('ArrowUp');
await page.keyboard.down('ArrowRight');
await page.waitForTimeout(1500);
await page.keyboard.up('ArrowRight');
await page.keyboard.up('Space');
await page.screenshot({ path: '/tmp/ufo_play.png' });

console.log('✓ screenshots written: /tmp/ufo_title.png, /tmp/ufo_play.png');
await browser.close();
