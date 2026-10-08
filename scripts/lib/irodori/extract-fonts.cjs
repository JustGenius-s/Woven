// PDF.js repairs embedded PDF font programs; record Unicode ↔ repaired glyph mapping.
const fs = require('node:fs/promises');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { createHash } = require('node:crypto');
async function main() {
  const [source, output] = process.argv.slice(2);
  if (!source || !output) throw new Error('Usage: extract-fonts.cjs source.pdf output-directory');
  await fs.mkdir(output, { recursive: true });
  const bytes = await fs.readFile(source);
  const pdfjs = await import(pathToFileURL(require.resolve('pdfjs-dist/legacy/build/pdf.mjs')).href);
  const doc = await pdfjs.getDocument({ data: new Uint8Array(bytes), fontExtraProperties: true,
    disableFontFace: false, verbosity: 0 }).promise;
  const fonts = new Map();
  try {
    for (let number = 1; number <= doc.numPages; number++) {
      const page = await doc.getPage(number);
      const list = await page.getOperatorList();
      let active;
      const stack = [];
      for (let i = 0; i < list.fnArray.length; i++) {
        const op = list.fnArray[i], args = list.argsArray[i];
        if (op === pdfjs.OPS.save) stack.push(active);
        else if (op === pdfjs.OPS.restore) active = stack.pop();
        else if (op === pdfjs.OPS.setFont) {
          active = args[0];
          if (!fonts.has(active)) {
            const font = page.commonObjs.get(active);
            if (!font.data?.length) {
              // Type 3 glyphs are PDF graphics, not embeddable OpenType fonts.
              if (font.isType3Font) { fonts.set(active, null); continue; }
              throw new Error(`Missing embedded font ${font.name}`);
            }
            fonts.set(active, { name: font.name.replace(/^[A-Z]{6}\+/, ''),
              file: `${active}.bin`, data: font.data, glyphs: {}, ligatures: {}, alternates: {} });
          }
        } else if (op === pdfjs.OPS.showText || op === pdfjs.OPS.showSpacedText) {
          const font = fonts.get(active);
          if (!font) continue;
          for (const glyph of args[0]) {
            if (typeof glyph !== 'object' || !glyph.unicode) continue;
            if ([...glyph.unicode].length !== 1) {
              // PDF text extraction expands Latin ligatures. Keep their mapping for
              // audit; regular f/i/l glyphs used by live text are checked separately.
              font.ligatures[glyph.unicode] = glyph.fontChar.codePointAt(0);
              continue;
            }
            const key = glyph.unicode.codePointAt(0);
            const value = glyph.fontChar.codePointAt(0);
            if (font.glyphs[key] !== undefined && font.glyphs[key] !== value) {
              font.alternates[key] = [...new Set([...(font.alternates[key] || []), value])];
              continue;
            }
            font.glyphs[key] = value;
          }
        }
      }
    }
    const records = [];
    for (const [id, font] of fonts) {
      if (!font) continue;
      await fs.writeFile(path.join(output, font.file), font.data);
      const { data, ...record } = font;
      records.push({ id, ...record });
    }
    await fs.writeFile(path.join(output, 'fonts.json'), JSON.stringify({
      sourceSha256: createHash('sha256').update(bytes).digest('hex'), fonts: records
    }, null, 2));
    console.log(`Extracted ${records.length} embedded font subsets for all ${doc.numPages} pages.`);
  } finally { await doc.destroy(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
