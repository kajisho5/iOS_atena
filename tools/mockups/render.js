// Renders every <name>.html in the given directory to <name>.png at its declared size.
// Usage: node tools/mockups/render.js <dir> <out-dir>
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const [dir, outDir] = process.argv.slice(2);
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.html'))) {
    const name = path.basename(file, '.html');
    const [width, height] = fs.readFileSync(path.join(dir, `${name}.size`), 'utf8').split('x').map(Number);
    const page = await browser.newPage({ viewport: { width, height } });
    await page.goto('file://' + path.resolve(dir, file));
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.join(outDir, `${name}.png`) });
    await page.close();
    console.log(`${name}.png ${width}x${height}`);
  }
  await browser.close();
})();
