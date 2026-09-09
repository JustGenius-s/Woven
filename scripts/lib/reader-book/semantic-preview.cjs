const fs = require('node:fs');
const path = require('node:path');
const escape = value => String(value??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const n = value => Number(value.toFixed(5));

function textStyle(g,base) {
  return `font-family:source-${g.font};font-size:${n(g.size/base)}em;color:${g.fill};`+
    (g.stroke!=='transparent'&&g.strokeEm?`-webkit-text-stroke:${g.strokeEm}em ${g.stroke};paint-order:stroke fill;`:'')+
    (g.underline?`text-decoration:underline;text-decoration-color:${g.underline};text-underline-offset:.13em;text-decoration-thickness:.065em;`:'');
}

function flowText(glyphs,base) {
  const runs=[];
  for(const g of glyphs) {
    if(g.kind==='ruby'){runs.push({ruby:g});continue;}
    if(g.kind==='rule'){runs.push({rule:g.widthEm});continue;}
    if(g.kind==='blank'){runs.push({blank:g.widthEm});continue;}
    const style=textStyle(g,base),last=runs.at(-1);
    if(last?.style===style)last.text+=g.text;
    else runs.push({style,text:g.text});
  }
  return runs.map(r=>r.ruby?`<ruby>${flowText(r.ruby.base,base)}<rt>${flowText(r.ruby.reading,base)}</rt></ruby>`:
    r.rule?`<span class="writing-rule" style="width:${n(r.rule)}em" aria-label="記入欄"></span>`:
    r.blank?`<span class="answer-slot" style="width:${n(r.blank)}em" aria-label="記入欄"></span>`:
    `<span style="${escape(r.style)}">${escape(r.text)}</span>`).join('');
}

function renderBlock(block, chapter, assetUrl) {
  const base=chapter.baseSize, text=gs=>flowText(gs,base);
  const lines=rows=>(rows||[]).map(row=>`<p>${text(row)}</p>`).join('');
  const render=child=>child?renderBlock(child,chapter,assetUrl):'';
  if(block.kind==='source-section')return `<section class="semantic-content source-section" id="${block.id}">${block.blocks.map(b=>renderBlock(b,{...chapter,baseSize:block.baseSize},assetUrl)).join('\n')}</section>`;
  if(block.kind==='multi-panel')return `<div class="sentence-panel full-panel${block.rounded?' rounded':''}${block.dashed?' dashed':''}" style="--panel-color:${block.background};--edge-color:#fff"><div class="sentence-border">`+
    block.rows.map(row=>{
      if(!row.groups.length)return `<div class="panel-text">${text(row.outside)}</div>`;
      const parts=[...row.groups.map(g=>({x:g.rect[0],group:g})),...row.outside.filter(g=>g.text.trim()).map(g=>({x:g.x,glyph:g}))].sort((a,b)=>a.x-b.x);
      return '<div class="sentence">'+parts.map(part=>part.group?`<div class="sentence-part"><div class="joined-cells">${part.group.cells.map(cell=>
        `<div class="sentence-cell"><span class="cell-value">${lines(cell.rows)}</span>${cell.slot?`<span class="cell-slot" style="width:${n(cell.slot.widthEm)}em" aria-hidden="true"></span>`:''}</div>`).join('')}</div></div>`:
        `<span class="sentence-punctuation">${text([part.glyph])}</span>`).join('')+'</div>';
    }).join('')+'</div></div>';
  if(block.kind==='cards')return `<div class="source-cards" style="--card-width:${n(block.cardWidthEm)}em;max-width:${n(block.widthEm)}em">`+
    block.items.map(item=>`<div class="source-card" id="${item.id}" style="${item.border?`border:.055em solid ${item.border};`:''}${item.background?`background:${item.background};`:''}">`+
      `<div class="card-before">${lines(item.before)}</div>`+
      (item.picture?`<div class="source-art-frame" style="--frame-ratio:${n(item.frameHeight/item.frameWidth*100)}%;--art-width:${n(item.picture.width/item.frameWidth*100)}%">${render(item.picture)}</div>`:'')+
      `<div class="card-after">${lines(item.after)}</div></div>`).join('')+'</div>';
  if(block.kind==='table')return `<div class="source-table-scroll"><table class="source-table${block.writing?' writing-table':''}${block.compact?' compact-table':''}${block.calendar?' calendar-table':''}" style="--table-border:${block.borderColor};${block.writing?'width:100%;':''}"><tbody>`+
    block.rows.map(row=>'<tr>'+row.map(cell=>`<td colspan="${cell.colSpan}" rowspan="${cell.rowSpan}" style="${cell.background?`background:${cell.background};`:''}">${lines(cell.rows)||'<span class="empty-cell" aria-label="記入欄"></span>'}</td>`).join('')+'</tr>').join('')+'</tbody></table></div>';
  if(block.kind==='parallel')return '<div class="parallel-tables">'+block.items.map(item=>`<table class="source-pairs${item.border?' bordered':''}" style="--table-border:${item.borderColor}"><tbody>`+
    item.rows.map(row=>`<tr><td style="${row.leftBackground?`background:${row.leftBackground};`:''}">${text(row.left)}</td><td style="${row.rightBackground?`background:${row.rightBackground};`:''}">${text(row.right)}</td></tr>`).join('')+'</tbody></table>').join('')+'</div>';
  if(block.kind==='image-row')return `<div class="source-image-row${block.routine?' routine-row':''}">`+
    (block.routine&&block.pictures[0]?`<div class="routine-clock">${render(block.pictures[0])}</div>`:'')+
    `<div class="row-text">${lines(block.rows)}</div><div class="row-pictures">${block.pictures.slice(block.routine?1:0).map(render).join('')}</div></div>`;
  if(block.kind==='paired-row')return `<div class="source-paired-row"><div class="row-number">${lines(block.number)}</div><div class="paired-items">${block.items.map(item=>
    `<div class="paired-item"><div>${lines(item.rows)}</div><div class="row-pictures">${item.pictures.map(render).join('')}</div></div>`).join('')}</div></div>`;
  if(block.kind==='greeting')return `<div class="source-greeting"><div class="greeting-turns">${block.turns.map(turn=>`<div class="greeting-turn"><div class="portrait">${render(turn.picture)}</div><div class="row-text">${lines(turn.rows)}</div></div>`).join('')}</div><div class="greeting-scene">${render(block.scene)}</div></div>`;
  if(block.kind==='blank-area')return '<div class="source-blank-area" aria-label="メモ欄"></div>';
  if(block.kind==='cover')return `<div class="source-cover${block.background?' framed':''}" style="${block.background?`--cover-color:${block.background};`:''}"><div class="cover-kicker">${render(block.kicker)}</div><div class="cover-bands">`+
    block.bands.map((band,i)=>`<div class="cover-band ${i?'lower-band':''}">${render(band)}</div>`).join('')+'</div>'+(block.publisher?`<div class="cover-publisher">${render(block.publisher)}</div>`:'')+'</div>';
  if(block.kind==='toc')return '<nav class="source-toc" aria-label="もくじ">'+block.items.map(item=>`<a class="toc-row" href="${assetUrl.chapterLink?assetUrl.chapterLink(item.target):'#'+item.target}"><span class="toc-number">${text(item.number)}</span><div>${lines(item.rows)}</div><span class="toc-page">${text(item.page)}</span></a>`).join('')+'</nav>';
  if(block.kind==='colophon')return `<div class="source-colophon">${lines(block.rows)}</div>`;
  if(block.kind==='callout-diagram')return `<div class="source-callout-diagram"><div class="callout-boxes">${block.items.map(item=>`<div class="callout-box" style="border-color:${item.borderColor};${item.background?`background:${item.background};`:''}">${lines(item.rows)}</div>`).join('')}</div>${lines(block.rows)}${render(block.figure)}</div>`;
  if(block.kind==='heading')return `<h2 class="source-heading${block.rounded?' rounded':''}" style="background:${block.background||'transparent'}">${text(block.glyphs)}</h2>`;
  if(block.kind==='conversation')return '<div class="conversation">'+block.turns.map(turn=>
    `<div class="conversation-turn"><div class="speaker">${text(turn.speaker)}</div><div class="speech">${turn.lines.map(line=>`<p>${text(line)}</p>`).join('')}</div></div>`).join('')+(block.figures||[]).map(render).join('')+'</div>';
  if(block.kind==='panel')return `<div class="sentence-panel" style="--panel-color:${block.background};--edge-color:${block.borderColor}"><div class="sentence-border"><div class="sentence">`+
    block.groups.map((group,index)=>`<div class="sentence-part"><div class="joined-cells">`+group.cells.map(cell=>
      `<div class="sentence-cell"><span class="cell-value">${text(cell.glyphs)}</span>`+
      (cell.slot?`<span class="cell-slot" style="width:${n(cell.slot.widthEm)}em" aria-hidden="true"></span>`:'')+'</div>').join('')+'</div>'+
      (index===block.groups.length-1&&block.punctuation.length?`<span class="sentence-punctuation">${text(block.punctuation)}</span>`:'')+'</div>').join('')+'</div></div></div>';
  if(block.kind==='paragraph')return `<div class="source-paragraph">${block.rows.map(row=>`<p>${text(row)}</p>`).join('')}</div>`;
  if(block.kind==='figure')return `<figure class="illustration" style="width:${n(block.width/base)}em"><img src="${assetUrl(block.asset)}" width="${Math.round(block.width)}" height="${Math.round(block.height)}" alt="${escape(block.alt)}"/></figure>`;
  if(block.kind==='diagram') {
    const glyph = g => `<text x="${n(g.x)}" y="${n(g.y)}" font-family="source-${g.font}" font-size="${n(g.size)}" fill="${g.fill}"`+
      (g.stroke!=='transparent'&&g.strokeEm?` stroke="${g.stroke}" stroke-width="${n(g.strokeEm*g.size)}" paint-order="stroke fill"`:'')+`>${escape(g.text)}</text>`;
    return `<figure class="annotated-figure" id="${block.id}" style="width:${n(block.width/base)}em"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${block.width} ${block.height}" role="img" aria-label="${escape(block.alt)}">`+
      `<title>${escape(block.alt)}</title><g class="diagram-image"><image width="${block.width}" height="${block.height}" href="${assetUrl(block.asset)}"/></g>`+
      '<g class="diagram-leaders" aria-hidden="true"></g><g class="diagram-labels">'+block.labels.map(label=>`<g>${label.glyphs.map(glyph).join('')}</g>`).join('')+'</g></svg></figure>';
  }
  throw new Error(`Unknown semantic block ${block.kind}`);
}

function preview(model,assets,workDir) {
  const assetUrl=name=>`data:image/png;base64,${assets.get(name).toString('base64')}`;
  const fonts=Object.entries(model.fonts).map(([name,file])=>`@font-face{font-family:source-${name};src:url(data:font/woff;base64,${fs.readFileSync(path.join(workDir,file)).toString('base64')}) format('woff');font-weight:normal;font-style:normal;font-display:block;}`).join('\n');
  const css=fs.readFileSync(path.join(__dirname,'semantic-preview.css'),'utf8');
  const script=fs.readFileSync(path.join(__dirname,'semantic-diagram.js'),'utf8');
  const diagrams=model.chapters.flatMap(chapter=>collectDiagrams(chapter.blocks,chapter.baseSize));
  return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>${escape(model.title)}</title><style>${fonts}\n${css}</style></head><body>
<header class="controls"><strong>${model.schemaVersion===2?'全书重排版':'转换试版'}</strong><nav>${model.chapters.length>4?`<select aria-label="章节" onchange="location.hash=this.value">${model.chapters.map(c=>`<option value="${c.id}">${escape(c.navTitle)}</option>`).join('')}</select>`:model.chapters.map(c=>`<a href="#${c.id}">${escape(c.navTitle)}</a>`).join('')}</nav>
<label>字号 <input id="font-size" type="range" min="16" max="40" step="1" value="22"/><output id="font-value">22</output></label>
<label>行距 <input id="line-height" type="range" min="1.3" max="2.3" step="0.1" value="1.7"/><output id="line-value">1.7</output></label></header>
<main id="reading" lang="ja">${model.chapters.map(c=>`<article id="${c.id}" class="chapter">${c.blocks.map(b=>renderBlock(b,c,assetUrl)).join('\n')}</article>`).join('\n')}</main>
<script id="diagram-data" type="application/json">${JSON.stringify(diagrams).replace(/</g,'\\u003c')}</script><script>${script}</script></body></html>`;
}

function collectDiagrams(blocks,baseSize) {
  const diagrams=[];
  const visit=value=>{
    if(!value||typeof value!=='object')return;
    if(Array.isArray(value)){value.forEach(visit);return;}
    if(value.kind==='diagram'){diagrams.push({...value,baseSize});return;}
    for(const [key,child] of Object.entries(value))if(!['glyphs','rows','before','after','fonts','source'].includes(key))visit(child);
  };
  visit(blocks);return diagrams;
}

module.exports={preview,renderBlock,collectDiagrams};
