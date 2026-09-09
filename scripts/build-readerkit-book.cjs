const fs = require('node:fs/promises');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const JSZip = require('jszip');
const { buildModel } = require('./lib/reader-book/semantic-layout.cjs');
const { buildFullModel } = require('./lib/reader-book/semantic-full-layout.cjs');
const { readGraphics } = require('./lib/reader-book/pdf-graphics.cjs');
const { chapterXhtml, css, fullCss, escape } = require('./lib/reader-book/readerkit-epub.cjs');
const root = path.resolve(__dirname, '..');
const option = (name, fallback) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback;

async function main({ full = false } = {}) {
  const config = full ? require('../content/reader-semantic-full/book.cjs') :
    JSON.parse(await fs.readFile(path.join(root, 'content/reader-semantic-trial/book.json'), 'utf8'));
  const editionId = full ? 'yaramaika-readerkit' : 'yaramaika-readerkit-trial';
  const python = option('--python', 'python');
  const source = path.resolve(root, option('--source', '.cache/reader-semantic-full-source'));
  if (process.argv.includes('--refresh-source')) {
    const pdf = option('--pdf');
    if (!pdf) throw new Error('--refresh-source requires --pdf /path/to/original.pdf');
    // Refresh only the trial cache; never replace the full-book source cache
    // with a two-page subset.
    if (!full && source === path.join(root, '.cache/reader-semantic-full-source')) {
      throw new Error('Use --source .cache/readerkit-trial-source when refreshing the two-page source.');
    }
    await fs.mkdir(source, { recursive: true });
    execFileSync(python, [path.join(__dirname, 'lib/reader-book/import-pdf2htmlex.py'), '--epub', path.join(root, config.fixedEpub),
      '--pages', config.pages.map(p => p.number).join(','), '--out', source], { windowsHide: true, stdio: 'pipe' });
    await fs.writeFile(path.join(source, 'pdf-graphics.json'), JSON.stringify(await readGraphics(pdf, config.pages.map(p => p.number), config.pdfSha256)));
  }
  const htmlSource = JSON.parse(await fs.readFile(path.join(source, 'html-source.json'), 'utf8'));
  const pdfSource = JSON.parse(await fs.readFile(path.join(source, 'pdf-graphics.json'), 'utf8'));
  if (pdfSource.sha256 !== config.pdfSha256) throw new Error('Source PDF does not match the approved trial profile.');
  const fixedHash = createHash('sha256').update(await fs.readFile(path.join(root, config.fixedEpub))).digest('hex');
  if (htmlSource.sha256 !== fixedHash) throw new Error('Source HTML cache does not match the bundled original EPUB.');
  const { model, assets, audit } = (full ? buildFullModel : buildModel)(config, htmlSource, pdfSource, source);
  const work = path.join(root, full ? '.cache/readerkit-full-package' : '.cache/readerkit-trial-package');
  await fs.mkdir(path.join(work, 'images'), { recursive: true });
  await fs.writeFile(path.join(work, 'model.json'), JSON.stringify(model));
  for (const [name, bytes] of assets) await fs.writeFile(path.join(work, 'images', name), bytes);
  execFileSync(python, [path.join(__dirname, 'lib/reader-book/prepare-readerkit-assets.py'),
    '--model', path.join(work, 'model.json'), '--source', source, '--out', work], { windowsHide: true, stdio: 'pipe' });
  const prepared = JSON.parse(await fs.readFile(path.join(work, 'prepared.json'), 'utf8'));
  // Intrinsic dimensions belong on nested images as well as in CSS. In the
  // native paginator an auto-sized inline wrapper is not a reliable source
  // for an image's percentage width or its initial pagination height.
  prepared.imageSizes = {};
  const imageFiles = new Set([...assets.keys()].map(name => `images/${name}`));
  for (const filename of [...Object.values(prepared.diagrams), ...Object.values(prepared.cards)]) imageFiles.add(filename);
  for (const filename of imageFiles) {
    const data = assets.get(filename.slice('images/'.length)) || await fs.readFile(path.join(work, filename));
    if (data.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error(`Expected PNG image: ${filename}`);
    prepared.imageSizes[filename] = { width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
  }
  const zip = new JSZip(), date = new Date('2026-09-09T00:00:00Z');
  const add = (name, bytes, compression = 'DEFLATE') => zip.file(name, bytes, { date, createFolders: false, compression });
  add('mimetype', 'application/epub+zip', 'STORE');
  add('META-INF/container.xml', '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>');
  const manifest = [], spine = [];
  const usedImages = new Set();
  const item = (id, href, type, properties = '') => manifest.push(`<item id="${id}" href="${escape(href)}" media-type="${type}"${properties ? ` properties="${properties}"` : ''}/>`);
  for (const chapter of model.chapters) {
    const href = `text/${chapter.id}.xhtml`;
    const xhtml = chapterXhtml(chapter, prepared);
    add(`OEBPS/${href}`, xhtml);
    for (const match of xhtml.matchAll(/src="\.\.\/(images\/[^\"]+)"/g)) usedImages.add(match[1]);
    item(chapter.id, href, 'application/xhtml+xml');
    spine.push(`<itemref idref="${chapter.id}"/>`);
  }
  let fontCss = '';
  for (const [family, filename] of Object.entries(prepared.fonts)) {
    add(`OEBPS/${filename}`, await fs.readFile(path.join(work, filename)));
    item(`font-${family}`, filename, 'font/ttf');
    fontCss += `@font-face{font-family:source-${family};src:url(../${filename}) format('truetype');font-weight:normal;font-style:normal}\n`;
  }
  for (const [index, filename] of [...usedImages].entries()) {
    add(`OEBPS/${filename}`, await fs.readFile(path.join(work, filename)));
    item(`image-${index}`, filename, 'image/png');
  }
  add('OEBPS/styles/book.css', fontCss + css + (full ? fullCss : ''));
  item('css', 'styles/book.css', 'text/css');
  const navItems = model.chapters.map(c => `<li><a href="text/${c.id}.xhtml#${c.id}">${escape(c.navTitle)}</a></li>`).join('');
  add('OEBPS/nav.xhtml', '<?xml version="1.0" encoding="UTF-8"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja"><head><title>もくじ</title></head><body><nav epub:type="toc" id="toc"><h1>もくじ</h1><ol>' + navItems + '</ol></nav></body></html>');
  item('nav', 'nav.xhtml', 'application/xhtml+xml', 'nav');
  const uid = full ? `urn:woven:readerkit:${config.pdfSha256}:full` : `urn:woven:readerkit-trial:${config.pdfSha256}:11-17`;
  add('OEBPS/toc.ncx', `<?xml version="1.0" encoding="UTF-8"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="${uid}"/></head><docTitle><text>やらまいか日本語</text></docTitle><navMap>` +
    model.chapters.map((c, i) => `<navPoint id="nav-${i}" playOrder="${i + 1}"><navLabel><text>${escape(c.navTitle)}</text></navLabel><content src="text/${c.id}.xhtml#${c.id}"/></navPoint>`).join('') + '</navMap></ncx>');
  item('ncx', 'toc.ncx', 'application/x-dtbncx+xml');
  add('OEBPS/package.opf', `<?xml version="1.0" encoding="UTF-8"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id" xml:lang="ja"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="book-id">${uid}</dc:identifier><dc:title>やらまいか日本語 · Reader Kit${full ? '' : ' 试版'}</dc:title><dc:language>ja</dc:language><meta property="dcterms:modified">2026-09-09T00:00:00Z</meta><meta property="rendition:layout">reflowable</meta></metadata><manifest>${manifest.join('')}</manifest><spine toc="ncx" page-progression-direction="ltr">${spine.join('')}</spine></package>`);
  const bytes = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE', compressionOptions: { level: 9 } });
  const hash = createHash('sha256').update(bytes).digest('hex').slice(0, 20);
  const output = `entry/src/main/resources/rawfile/reader/${editionId}.epub`;
  await fs.writeFile(path.join(root, output), bytes);
  if (full) {
    await fs.writeFile(path.join(root, 'entry/src/main/ets/services/ReaderKitContent.ets'),
      '// Generated by scripts/build-readerkit-full.cjs.\n' +
      `export const READERKIT_ID: string = '${editionId}';\n` +
      `export const READERKIT_BYTES: number = ${bytes.length};\n` +
      `export const READERKIT_REVISION: number = 1;\n` +
      `export const READERKIT_CACHE: string = '${hash}';\n` +
      `export const READERKIT_TITLES: string[] = ${JSON.stringify(model.chapters.map(c => c.navTitle))};\n` +
      `export const READERKIT_CHAPTERS: string[] = ${JSON.stringify(model.chapters.map(c => c.id))};\n` +
      `export const READERKIT_CLASSROOM_INDEX: number = ${model.chapters.findIndex(c => c.id === 'classroom')};\n` +
      `export const READERKIT_SOURCE_PAGES: number[] = ${JSON.stringify(model.chapters.map(c => c.startPage - 1))};\n`);
    await fs.writeFile(path.join(work, 'audit.json'), JSON.stringify({ source: model.source,
      pages: audit, chapters: model.chapters.map(c => ({ id: c.id, pages: c.pages })),
      diagrams: Object.keys(prepared.diagrams), normalizedCards: Object.keys(prepared.cards), fonts: Object.keys(prepared.fonts) }, null, 2));
  } else await fs.writeFile(path.join(root, 'entry/src/main/ets/services/ReaderKitTrialContent.ets'),
    '// Generated by scripts/build-readerkit-trial.cjs. Physical PDF pages 11 and 17.\n' +
    `export const READERKIT_TRIAL_ID: string = 'yaramaika-readerkit-trial';\n` +
    `export const READERKIT_TRIAL_BYTES: number = ${bytes.length};\n` +
    `export const READERKIT_TRIAL_REVISION: number = 1;\n` +
    `export const READERKIT_TRIAL_CACHE: string = '${hash}';\n` +
    `export const READERKIT_TRIAL_TITLES: string[] = ${JSON.stringify(model.chapters.map(c => `PDF 第 ${c.sourcePage} 页 · ${c.navTitle}`))};\n` +
    `export const READERKIT_TRIAL_SOURCE_PAGES: number[] = ${JSON.stringify(model.chapters.map(c => c.sourcePage - 1))};\n`);
  console.log(JSON.stringify({ output, bytes: bytes.length, chapters: model.chapters.length, fonts: Object.keys(prepared.fonts).length,
    sourcePages: config.pages.length, images: usedImages.size, attachedDiagrams: Object.keys(prepared.diagrams).length,
    normalizedCards: Object.keys(prepared.cards).length, hash }, null, 2));
}

if (require.main === module) main({ full: process.argv.includes('--full') }).catch(error => { console.error(error.stack); process.exitCode = 1; });
module.exports = { main };
