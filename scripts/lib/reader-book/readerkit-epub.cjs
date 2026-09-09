// Script-free native EPUB adapter for the approved semantic textbook content.
// This is separate from the ArkWeb renderer and its live diagram layout.
const escape = value => String(value ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const n = value => Number(value.toFixed(5));

function flowText(glyphs, base) {
  const runs = [];
  for (const g of glyphs) {
    if (g.kind === 'ruby') {
      runs.push({ html: `<ruby>${flowText(g.base, base)}<rt>${flowText(g.reading, base)}</rt></ruby>` });
      continue;
    }
    if (g.kind === 'rule') {
      runs.push({ html: `<span class="writing-rule" style="width:${n(g.widthEm)}em" aria-label="記入欄">&#160;</span>` });
      continue;
    }
    if (g.kind === 'blank') {
      runs.push({ html: `<span class="answer-slot" style="width:${n(g.widthEm)}em" aria-label="記入欄">&#160;</span>` });
      continue;
    }
    if (g.kind) throw new Error(`Unsupported native text node: ${g.kind}`);
    const style = `font-family:source-${g.font} !important;font-size:${n(g.size / base)}em;color:${g.fill} !important;` +
      (g.stroke !== 'transparent' && g.strokeEm ? `-webkit-text-stroke:${g.strokeEm}em ${g.stroke};paint-order:stroke fill;` : '') +
      (g.underline ? `text-decoration:underline;text-decoration-color:${g.underline};` : '');
    const last = runs.at(-1);
    if (last?.style === style) last.text += g.text;
    else runs.push({ style, text: g.text });
  }
  return runs.map(r => r.html || `<span style="${escape(r.style)}">${escape(r.text)}</span>`).join('');
}

function renderBlock(block, chapter, prepared) {
  const text = gs => flowText(gs, chapter.baseSize);
  const id = `id="${escape(block.id)}"`;
  const lines = rows => (rows || []).map(row => `<p>${text(row)}</p>`).join('');
  const render = child => child ? renderBlock(child, chapter, prepared) : '';
  const picture = (child, limit) => nativePicture(child, chapter, prepared, limit);
  const pictureRow = (rows, pictures, clock) => '<table class="lesson-row" role="presentation" width="100%"><tbody><tr>' +
    (clock ? `<td class="lesson-clock">${picture(clock, 2.8)}</td>` : '') +
    `<td class="lesson-text">${lines(rows)}</td>` +
    (pictures.length ? `<td class="lesson-art" width="36%">${pictures.map(p => picture(p, 12)).join('')}</td>` : '') +
    '</tr></tbody></table>';
  if (block.kind === 'source-section') return `<div ${id} class="source-section">${block.blocks.map(b => renderBlock(b, { ...chapter, baseSize: block.baseSize }, prepared)).join('\n')}</div>`;
  if (block.kind === 'multi-panel') {
    return `<div ${id} class="sentence-panel full-panel${block.rounded ? ' rounded-panel' : ''}" style="background-color:${block.background}"><div class="sentence-border${block.dashed ? '' : ' solid-panel'}">` +
      block.rows.map(row => {
        if (!row.groups.length) return `<div class="panel-text">${text(row.outside)}</div>`;
        const parts = [...row.groups.map(group => ({ x: group.rect[0], group })),
          ...row.outside.filter(g => g.text.trim()).map(g => ({ x: g.x, glyph: g }))].sort((a, b) => a.x - b.x);
        return '<div class="panel-row">' + parts.map(part => part.group ? '<table class="sentence-part" role="presentation"><tbody><tr>' +
          part.group.cells.map(cell => `<td class="sentence-cell">${lines(cell.rows)}</td>` +
            (cell.slot ? `<td class="cell-slot" style="width:${n(cell.slot.widthEm)}em" aria-label="記入欄">&#160;</td>` : '')).join('') +
          '</tr></tbody></table>' : `<span class="punctuation">${text([part.glyph])}</span>`).join(' ') + '</div>';
      }).join('') + '</div></div>';
  }
  if (block.kind === 'cards') return `<div ${id} class="source-cards" style="max-width:${n(block.widthEm)}em">` + block.items.map(item => {
    const asset = item.picture ? prepared.cards[item.id] : '';
    if (item.picture && !asset) throw new Error(`Missing normalized card image ${item.id}`);
    return `<div class="source-card" id="${item.id}" style="width:${n(block.cardWidthEm)}em;${item.border ? `border:.055em solid ${item.border};` : ''}${item.background ? `background-color:${item.background};` : ''}">` +
      `<div class="card-before">${lines(item.before)}</div>` +
      (item.picture ? `<div class="card-art" id="${item.picture.id}"><img src="../${escape(asset)}" alt="${escape(figureAlt(item.picture))}"/></div>` : '') +
      `<div class="card-after">${lines(item.after)}</div></div>`;
  }).join(' ') + '</div>';
  if (block.kind === 'table') return `<div ${id} class="source-table-wrap"><table class="source-table${block.writing ? ' writing-table' : ''}${block.compact ? ' compact-table' : ''}${block.calendar ? ' calendar-table' : ''}"><tbody>` +
    block.rows.map(row => '<tr>' + row.map(cell => `<td colspan="${cell.colSpan}" rowspan="${cell.rowSpan}" style="border-color:${block.borderColor};${cell.background ? `background-color:${cell.background};` : ''}">${lines(cell.rows) || '<span class="empty-cell" aria-label="記入欄">&#160;</span>'}</td>`).join('') + '</tr>').join('') + '</tbody></table></div>';
  if (block.kind === 'parallel') return `<div ${id} class="parallel-tables">` + block.items.map(item => `<table class="source-pairs${item.border ? ' bordered' : ''}" style="border-color:${item.borderColor}"><tbody>` +
    item.rows.map(row => `<tr><td class="pair-left" style="border-color:${item.borderColor};${row.leftBackground ? `background-color:${row.leftBackground};` : ''}">${text(row.left)}</td><td style="${row.rightBackground ? `background-color:${row.rightBackground};` : ''}">${text(row.right)}</td></tr>`).join('') + '</tbody></table>').join(' ') + '</div>';
  if (block.kind === 'image-row') return `<div ${id} class="source-image-row">` +
    pictureRow(block.rows, block.pictures.slice(block.routine ? 1 : 0), block.routine ? block.pictures[0] : null) + '</div>';
  if (block.kind === 'paired-row') return `<div ${id} class="source-paired-row"><div class="row-number">${lines(block.number)}</div>` +
    block.items.map(item => `<div class="paired-item">${pictureRow(item.rows, item.pictures)}</div>`).join('') + '</div>';
  if (block.kind === 'greeting') return `<div ${id} class="source-greeting">` +
    block.turns.map((turn, index) => `<table class="greeting-turn${index === block.turns.length - 1 ? ' before-scene' : ''}" role="presentation" width="100%"><tbody><tr>` +
      `<td class="portrait">${picture(turn.picture, 2.6)}</td><td class="greeting-text">${lines(turn.rows)}</td></tr></tbody></table>`).join('') +
    `<div class="greeting-scene">${picture(block.scene, 12)}</div></div>`;
  if (block.kind === 'cover') return `<div ${id} class="source-cover" style="${block.background ? `border:.25em solid ${block.background};` : ''}"><div class="cover-kicker">${render(block.kicker)}</div>` +
    `<div class="cover-bands" style="${block.background ? `background-color:${block.background};` : ''}">` +
    block.bands.map((band, i) => `<div class="cover-band${i ? ' lower-band' : ''}">${render(band)}</div>`).join('') +
    `</div><div class="cover-publisher">${render(block.publisher)}</div></div>`;
  if (block.kind === 'toc') return `<div ${id} class="source-toc">` + block.items.map(item => {
    const href = `${item.target}.xhtml#${item.target}`;
    return `<table class="toc-row" role="presentation"><tbody><tr><td class="toc-number"><a href="${href}">${text(item.number)}</a></td>` +
      `<td class="toc-title"><a href="${href}">${item.rows.map(text).join('<br/>')}</a></td><td class="toc-page"><a href="${href}">${text(item.page)}</a></td></tr></tbody></table>`;
  }).join('') + '</div>';
  if (block.kind === 'colophon') return `<div ${id} class="source-colophon">${lines(block.rows)}</div>`;
  if (block.kind === 'blank-area') return `<div ${id} class="source-blank-area" aria-label="メモ欄">&#160;</div>`;
  if (block.kind === 'callout-diagram') return `<div ${id} class="source-callout-diagram"><div class="callout-boxes">` +
    block.items.map(item => `<div class="callout-box" style="border-color:${item.borderColor};${item.background ? `background-color:${item.background};` : ''}">${lines(item.rows)}</div>`).join(' ') +
    `</div>${lines(block.rows)}${render(block.figure)}</div>`;
  if (block.kind === 'heading') return `<h2 ${id} class="source-heading${block.rounded ? ' rounded' : ''}" style="background-color:${block.background || 'transparent'}">${text(block.glyphs)}</h2>`;
  if (block.kind === 'conversation') return `<div ${id} class="conversation">` + block.turns.map(turn =>
    '<div class="conversation-turn">' + turn.lines.map((line, i) =>
      `<p class="${i ? 'continuation' : 'speech'}">${i ? '' : `<span class="speaker">${text(turn.speaker)}</span> `}${text(line)}</p>`).join('') + '</div>').join('') + (block.figures || []).map(render).join('') + '</div>';
  if (block.kind === 'paragraph') return `<div ${id} class="source-paragraph">${block.rows.map(row => `<p>${text(row)}</p>`).join('')}</div>`;
  if (block.kind === 'panel') {
    const edge = block.borderColor;
    return `<div ${id} class="sentence-panel" style="background-color:${block.background}"><div class="sentence-border" style="border-color:${edge}">` +
      block.groups.map((group, index) => '<table class="sentence-part" role="presentation"><tbody><tr>' +
        group.cells.map(cell => `<td class="sentence-cell" style="border-color:${edge}">${text(cell.glyphs)}</td>` +
          (cell.slot ? `<td class="cell-slot" style="width:${n(cell.slot.widthEm)}em;border-color:${edge}" aria-label="記入欄">&#160;</td>` : '')).join('') +
        (index === block.groups.length - 1 && block.punctuation.length ? `<td class="punctuation">${text(block.punctuation)}</td>` : '') +
        '</tr></tbody></table>').join(' ') + '</div></div>';
  }
  if (block.kind === 'figure' || block.kind === 'diagram') {
    const asset = block.kind === 'diagram' ? prepared.diagrams[block.id] : `images/${block.asset}`;
    if (!asset) throw new Error(`Missing attached diagram ${block.id}`);
    const alt = figureAlt(block);
    return `<div ${id} class="illustration" style="width:${n(block.width / chapter.baseSize)}em"><img src="../${escape(asset)}" alt="${escape(alt)}"/></div>`;
  }
  throw new Error(`Unsupported native block: ${block.kind}`);
}

function figureAlt(block) {
  return (block.alt || '挿絵') + (block.kind === 'diagram' ? '：' + block.labels.map(label => label.text).join('、') : '');
}

// Use a real image with its own dimensions, rather than a percentage-sized
// child of nested shrink-to-fit wrappers. em width still follows text size;
// max-width constrains it to the actual column and height keeps its aspect.
function nativePicture(block, chapter, prepared, limit) {
  if (!block) return '';
  const asset = block.kind === 'diagram' ? prepared.diagrams[block.id] : `images/${block.asset}`;
  const size = prepared.imageSizes[asset];
  if (!size?.width || !size.height) throw new Error(`Missing image dimensions: ${block.id}`);
  return `<img class="native-illustration" id="${escape(block.id)}" src="../${escape(asset)}" alt="${escape(figureAlt(block))}"` +
    ` width="${size.width}" height="${size.height}" style="width:${n(Math.min(block.width / chapter.baseSize, limit))}em;max-width:100%;height:auto"/>`;
}

const css = `
html,body{margin:0;padding:0;background:#fff;color:#231f20}
body{font-family:source-ff1,sans-serif;text-align:left;text-indent:0;font-weight:normal}
.chapter{margin:0 auto;padding:.6em .55em 1em;max-width:30em}
p{margin:0;text-indent:0;text-align:left;orphans:2;widows:2}
span{font-weight:normal;letter-spacing:normal;word-spacing:normal}
.source-heading{font-size:1em;font-weight:normal;line-height:1.35;margin:0 0 1em;padding:.45em .55em;page-break-after:avoid;break-after:avoid}
.rounded{border-radius:.55em}
.conversation{margin:.4em 0 1em}
.conversation-turn{margin:0 0 .9em}
.speaker{white-space:nowrap}
.continuation{margin-left:1em}
.source-paragraph{margin:.8em 0 1em}
.answer-slot{display:inline-block;vertical-align:baseline;height:1.15em;max-width:90%;border:.05em solid #747474;margin:0 .18em;line-height:1}
.illustration{max-width:100%;margin:1em auto;padding:0;page-break-inside:avoid;break-inside:avoid}
.illustration img{display:block;width:100%;height:auto}
.sentence-panel{border-radius:.7em;margin:1em 0;padding:.3em;page-break-inside:avoid;break-inside:avoid}
.sentence-border{border:.2em dashed #fff;border-radius:.6em;padding:.4em .2em;text-align:center}
.sentence-part{display:inline-table;border-collapse:collapse;border-spacing:0;vertical-align:middle;margin:.25em .18em;max-width:100%;line-height:1.4;page-break-inside:avoid;break-inside:avoid}
.sentence-cell{border:.055em solid #fff;padding:.24em .3em;text-align:center;vertical-align:middle;white-space:normal}
.cell-slot{border:.055em solid #fff;border-left:.07em dotted #fff;padding:0;min-width:.65em}
.punctuation{border:0;padding:0 0 0 .12em;vertical-align:middle}
`;

// Extend only the full book; the approved two-page CSS remains unchanged.
const fullCss = `
.source-section{margin:0 0 1.2em;padding:0}
ruby{ruby-position:over;ruby-align:center}
rt{font-size:1em;line-height:1;text-align:center}
.writing-rule{display:inline-block;max-width:100%;min-height:1.5em;border-bottom:.05em solid #707b7b;vertical-align:baseline;margin:.1em .2em}
.full-panel{border-radius:0}
.rounded-panel{border-radius:.7em}
.solid-panel{border:0;border-radius:0}
.panel-row+.panel-row,.panel-text+.panel-text{margin-top:.6em}
.sentence-cell p{text-align:center}
.source-cards{margin:.8em auto;text-align:center}
.source-card{display:inline-block;box-sizing:border-box;max-width:100%;vertical-align:top;padding:.3em;margin:.3em .15em;page-break-inside:avoid;break-inside:avoid}
.source-card p{text-align:center;margin:0;line-height:1.4}
.card-before{margin:0 0 .3em}
.card-after{margin:.3em 0 0}
.card-art img{display:block;width:100%;height:auto}
.source-table-wrap{margin:.8em 0;max-width:100%}
.source-table{border-collapse:collapse;border-spacing:0;width:100%;table-layout:fixed;line-height:1.35}
.source-table td{border:.05em solid #707b7b;padding:.2em .25em;text-align:center;vertical-align:middle;overflow-wrap:break-word;word-wrap:break-word}
.source-table p{text-align:center}
.source-table tr{page-break-inside:avoid;break-inside:avoid}
.source-table td p+p{margin-top:.16em}
.source-table .empty-cell{display:block;min-height:1.4em}
.compact-table td{padding:.12em .08em}
.calendar-table td{padding:.15em .08em}
.writing-table td{height:2.5em;text-align:left}
.writing-table td p{text-align:left}
.parallel-tables{margin:.8em 0;text-align:center}
.source-pairs{display:inline-table;border-collapse:collapse;max-width:100%;margin:.3em;vertical-align:top;line-height:1.5}
.source-pairs td{padding:.15em .3em;text-align:left}
.source-pairs .pair-left{border-right:.045em solid #707b7b}
.source-pairs.bordered{border:.05em solid}
.source-pairs tr{page-break-inside:avoid;break-inside:avoid}
.source-image-row,.source-paired-row{display:block;width:100%;margin:.65em 0}
.lesson-row{width:100%;table-layout:fixed;border-collapse:collapse;margin:.3em 0}
.lesson-row tr{page-break-inside:avoid;break-inside:avoid}
.lesson-text{vertical-align:middle;padding:.15em .4em .15em 0}
.lesson-art{width:36%;vertical-align:middle;text-align:center;padding:.15em 0}
.lesson-clock{width:3.2em;vertical-align:middle;padding-right:.35em}
.native-illustration{display:block;max-width:100%;height:auto;margin:.15em auto;page-break-inside:avoid;break-inside:avoid}
.row-number{margin-bottom:.3em}
.paired-item{display:block;width:100%;margin:.3em 0}
.source-greeting{display:block;width:100%;margin:.8em 0;page-break-inside:auto;break-inside:auto}
.greeting-turn{width:100%;table-layout:fixed;border-collapse:collapse;margin:.4em 0}
.greeting-turn tr{page-break-inside:avoid;break-inside:avoid}
.portrait{width:3em;vertical-align:middle;padding-right:.4em}
.greeting-text{vertical-align:middle}
.before-scene{page-break-after:avoid;break-after:avoid}
.greeting-scene{display:block;width:100%;margin:.3em 0;page-break-inside:avoid;break-inside:avoid}
.source-cover{padding:.7em;margin:0 auto 1em;max-width:100%}
.cover-kicker{margin:0 0 2em;max-width:18em}
.cover-kicker .illustration{margin:0}
.cover-bands{padding:.3em;margin:0 0 2em}
.cover-band .illustration{margin:.65em auto}
.lower-band .illustration{margin-left:auto;margin-right:0;max-width:74%}
.cover-publisher{max-width:8em;margin:0 auto}
.source-toc{margin:.6em 0 1em}
.toc-row{border-collapse:collapse;width:100%;line-height:1.5;margin:.6em 0;page-break-inside:avoid;break-inside:avoid}
.toc-row td{vertical-align:baseline;padding:.2em 0}
.toc-row a{color:inherit;text-decoration:none}
.toc-number{width:2.4em;white-space:nowrap}
.toc-page{width:2em;white-space:nowrap;text-align:right;border-left:.04em solid #231f20}
.toc-title{padding-right:.5em!important}
.source-colophon{margin:2em auto;max-width:100%}
.source-colophon p{margin:0 0 1.1em}
.source-colophon p:nth-child(-n+4){text-align:center}
.source-blank-area{min-height:20em}
.source-callout-diagram{margin:1em 0;page-break-inside:avoid;break-inside:avoid}
.callout-box{display:inline-block;border:.07em solid;padding:.3em .4em;max-width:100%;vertical-align:middle;margin:.3em}
.callout-box p{text-align:center}
`;

function chapterXhtml(chapter, prepared) {
  return '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n' +
    '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja"><head>' +
    `<title>${escape(chapter.navTitle)}</title><link rel="stylesheet" type="text/css" href="../styles/book.css"/></head>` +
    `<body><div class="chapter" id="${escape(chapter.id)}">${chapter.blocks.map(block => renderBlock(block, chapter, prepared)).join('\n')}</div></body></html>`;
}

module.exports = { chapterXhtml, css, fullCss, escape };
