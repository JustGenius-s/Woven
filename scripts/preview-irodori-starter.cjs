// Render every Starter XHTML at phone width and check images, fonts and overflow.
// NODE_PATH must provide playwright; pass an installed Chromium executable.
const fs = require('node:fs/promises');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');
async function main() {
  const args = process.argv.slice(2);
  const option = (name, fallback) => args.includes(name) ? args[args.indexOf(name) + 1] : fallback;
  const cache = path.resolve(option('--cache', '.cache/irodori-starter'));
  const output = path.resolve(option('--output', '.cache/irodori-starter/preview'));
  const lessons = option('--lessons', '0,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18').split(',').map(Number);
  const browser = await chromium.launch({ headless: true, executablePath: option('--browser', undefined) });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const results = [];
  await fs.mkdir(output, { recursive: true });
  try {
    for (const lesson of lessons) {
      const id = String(lesson).padStart(2, '0');
      const directory = path.join(cache, `l${id}`);
      const audit = JSON.parse(await fs.readFile(path.join(directory, 'audit.json'), 'utf8'));
      for (let n = 1; n <= audit.pageCount; n++) {
        await page.goto(pathToFileURL(path.join(directory, `p${n}.xhtml`)).href);
        await page.addStyleTag({ content: 'body{font-size:18px}' });
        await page.evaluate(() => document.fonts.ready);
        await page.screenshot({ path: path.join(output, `l${id}-p${n}.png`), fullPage: true });
        results.push({ lesson, page: n, epubSha256: audit.epubSha256, ...await page.evaluate(() => ({
          width: document.documentElement.scrollWidth,
          height: document.documentElement.scrollHeight,
          missingImages: [...document.images].filter(x => !x.complete || !x.naturalWidth).length,
          failedFonts: [...document.fonts].filter(x => x.status === 'error').length,
          overflow: [...document.querySelectorAll('body *')].filter(el => el.getBoundingClientRect().right > 392).map(el => el.tagName + ':' + el.className).slice(0, 8),
          tallEmptyImages: [...document.images].filter(el => !el.alt && el.getBoundingClientRect().height > 750).length
        })) });
      }
      console.log(`Rendered L${id}: ${audit.pageCount} pages`);
    }
    await fs.writeFile(path.join(output, `browser-audit-${lessons.join('-')}.json`), JSON.stringify(results, null, 2));
    const failures = results.filter(r => r.missingImages || r.failedFonts || r.overflow.length || r.tallEmptyImages);
    console.log(JSON.stringify({ pages: results.length, failures }, null, 2));
    if (failures.length) process.exitCode = 1;
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
