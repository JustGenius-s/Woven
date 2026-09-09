const fs = require('node:fs');
const path = require('node:path');
const { PNG } = require('pngjs');

const inside = (x,y,r,pad=0) => x>=r[0]-pad && x<=r[2]+pad && y>=r[1]-pad && y<=r[3]+pad;
const area = r => (r[2]-r[0])*(r[3]-r[1]);
const center = r => [(r[0]+r[2])/2,(r[1]+r[3])/2];
const near = (a,b,t=3) => Math.abs(a-b)<t;
const isWhite = color => /^#f[ef]f[ef]f[ef]$/i.test(color || '');
const visible = g => g.fill!=='transparent' || (g.stroke!=='transparent' && g.strokeEm);

function rowsOf(glyphs) {
  const rows=[];
  for(const g of [...glyphs].sort((a,b)=>a.y-b.y||a.x-b.x)) {
    let row=rows.find(r=>Math.abs(r.y-g.y)<Math.min(r.size,g.size)*.28);
    if(!row)rows.push(row={y:g.y,size:g.size,glyphs:[]});
    row.glyphs.push(g);
  }
  for(const row of rows)row.glyphs.sort((a,b)=>a.x-b.x);
  return rows;
}

function trimmed(glyphs) {
  let start=0,end=glyphs.length;
  while(start<end&&!glyphs[start].text.trim())start++;
  while(end>start&&!glyphs[end-1].text.trim())end--;
  return glyphs.slice(start,end);
}

function withSpaces(glyphs) {
  const out=[];
  for(const g of trimmed(glyphs)) {
    const last=out.at(-1);
    if(last&&last.text.trim()&&g.text.trim()&&g.x-last.x-last.advance>g.size*.45)
      out.push({...g,text:' ',advance:0,synthetic:true});
    out.push(g);
  }
  return out;
}

function addUnderlines(glyphs, shapes) {
  const lines=shapes.filter(s=>s.stroke&&!isWhite(s.stroke)&&!s.dash.length)
    .flatMap(s=>s.segments.filter(l=>near(l[1],l[3],.5)).map(l=>({x0:Math.min(l[0],l[2]),x1:Math.max(l[0],l[2]),y:l[1],color:s.stroke})));
  return glyphs.map(g=>{
    const underline=lines.find(l=>l.y>=g.y&&l.y-g.y<g.size*.4&&g.x+g.advance*.5>l.x0&&g.x+g.advance*.5<l.x1);
    return underline?{...g,underline:underline.color}:g;
  });
}

function backdrop(shapes, rect) {
  return shapes.filter(s=>s.fill&&s.fill!=='#ffffff'&&inside(...center(s.rect),rect)&&area(s.rect)>area(rect)*.15)
    .sort((a,b)=>area(b.rect)-area(a.rect))[0];
}

function mergeIntervals(intervals, tolerance=3) {
  const out=[];
  for(const interval of intervals.sort((a,b)=>a[0]-b[0])) {
    const last=out.at(-1);
    if(last&&interval[0]<=last[1]+tolerance)last[1]=Math.max(last[1],interval[1]);
    else out.push([...interval]);
  }
  return out;
}

function inferPanel(glyphs, shapes, rect, baseSize) {
  const bg=backdrop(shapes,rect);
  if(!bg)throw new Error('No colored container found for a panel region.');
  const edges=shapes.filter(s=>s.stroke&&isWhite(s.stroke)&&inside(...center(s.rect),bg.rect))
    .flatMap(s=>s.segments.map(l=>({l,dash:s.dash,width:s.lineWidth,color:s.stroke})));
  const horizontal=edges.filter(e=>!e.dash.length&&near(e.l[1],e.l[3],.7)&&Math.abs(e.l[0]-e.l[2])>baseSize*.5);
  const levels=[];
  for(const e of horizontal){let level=levels.find(v=>near(v.y,e.l[1]));if(!level)levels.push(level={y:e.l[1],edges:[]});level.edges.push(e);}
  levels.sort((a,b)=>a.y-b.y);
  const top=levels[0],bottom=levels.at(-1);
  if(!top||!bottom||bottom.y-top.y<baseSize)throw new Error('Panel cell borders are ambiguous.');
  const envelopes=mergeIntervals(top.edges.map(e=>[Math.min(e.l[0],e.l[2]),Math.max(e.l[0],e.l[2])]));
  const bottomEnvelopes=mergeIntervals(bottom.edges.map(e=>[Math.min(e.l[0],e.l[2]),Math.max(e.l[0],e.l[2])]));
  const groups=[], assigned=new Set();
  for(const [left,right] of envelopes) {
    if(!bottomEnvelopes.some(b=>near(b[0],left,5)&&near(b[1],right,5)))throw new Error('Panel top and bottom borders disagree.');
    const vertical=edges.filter(e=>near(e.l[0],e.l[2],.5)&&e.l[0]>=left-3&&e.l[0]<=right+3);
    const boundaries=[left,right,...vertical.filter(e=>!e.dash.length&&Math.abs(e.l[1]-e.l[3])>(bottom.y-top.y)*.75).map(e=>e.l[0])]
      .sort((a,b)=>a-b).filter((x,i,a)=>!i||!near(x,a[i-1],3));
    const cells=[];
    for(let i=0;i<boundaries.length-1;i++) {
      const cellRect=[boundaries[i],top.y,boundaries[i+1],bottom.y];
      const content=glyphs.filter(g=>inside(g.x+g.advance/2,g.y-g.size*.35,cellRect,1));
      content.forEach(g=>assigned.add(g));
      const divider=vertical.find(e=>e.dash.length&&e.l[0]>cellRect[0]+3&&e.l[0]<cellRect[2]-3);
      cells.push({sourceRect:cellRect,glyphs:withSpaces(content),
        ...(divider?{slot:{side:'end',widthEm:(cellRect[2]-divider.l[0])/baseSize,border:'dotted'}}:{})});
    }
    groups.push({kind:'joined-cells',sourceRect:[left,top.y,right,bottom.y],cells});
  }
  const outside=trimmed(glyphs.filter(g=>!assigned.has(g)));
  // Do not silently discard text which was not enclosed by a recovered cell.
  if(outside.some(g=>!/^[。、｡．.\s]$/.test(g.text)))throw new Error('Panel has unassigned non-punctuation text; review its region.');
  return {kind:'panel',background:bg.fill,rounded:bg.curved,borderColor:edges[0]?.color||'#fff',
    sourceRect:bg.rect,groups,punctuation:outside,evidence:'shared top/bottom edges and vertical cell boundaries'};
}

let backgroundPath,backgroundPixels;
function cropBackground(source, rect, workDir, assets, name) {
  const filename=path.join(workDir,source.background);
  if(backgroundPath!==filename){backgroundPath=filename;backgroundPixels=PNG.sync.read(fs.readFileSync(filename));}
  const page=backgroundPixels;
  const [x,y,w,h]=source.backgroundBox;
  const x0=Math.max(0,Math.floor((rect[0]-x)/w*page.width)),y0=Math.max(0,Math.floor((rect[1]-y)/h*page.height));
  const x1=Math.min(page.width,Math.ceil((rect[2]-x)/w*page.width)),y1=Math.min(page.height,Math.ceil((rect[3]-y)/h*page.height));
  if(x1<=x0||y1<=y0)throw new Error('Empty background region.');
  const png=new PNG({width:x1-x0,height:y1-y0});
  PNG.bitblt(page,png,x0,y0,png.width,png.height,0,0);
  assets.set(name,PNG.sync.write(png));
  // Report the actual rounded crop in the HTML coordinate system. Text uses
  // exactly this rectangle, not the requested rectangle or a second DPI ratio.
  return {asset:name,rect:[x+x0/page.width*w,y+y0/page.height*h,x+x1/page.width*w,y+y1/page.height*h]};
}

function inferLabels(glyphs, rect) {
  const labels=[];
  for(const row of rowsOf(glyphs)) {
    const parts=[];
    for(const g of row.glyphs) {
      if(!g.text.trim())continue;
      const previous=parts.at(-1)?.at(-1);
      if(!previous||g.x-previous.x-previous.advance>g.size*.65)parts.push([]);
      parts.at(-1).push(g);
    }
    for(const content of parts) {
      const x0=Math.min(...content.map(g=>g.x)),x1=Math.max(...content.map(g=>g.x+g.advance));
      const y0=Math.min(...content.map(g=>g.y-g.size*g.ascent)),y1=Math.max(...content.map(g=>g.y+g.size*g.descent));
      const anchor=[(x0+x1)/2-rect[0],row.y-rect[1]];
      labels.push({text:content.map(g=>g.text).join(''),anchor,
        side:anchor[1]<(rect[3]-rect[1])*.5?'top':'bottom',
        bounds:[x0-rect[0],y0-rect[1],x1-rect[0],y1-rect[1]],
        glyphs:content.map(g=>({...g,x:g.x-rect[0],y:g.y-rect[1]})),
        relation:'attached-to-figure',evidence:'same baseline and adjacent glyph advances'});
    }
  }
  return labels;
}

function buildModel(config, htmlSource, pdfSource, workDir) {
  const assets=new Map(), chapters=[];
  for(const definition of config.pages) {
    const source=htmlSource.pages.find(p=>p.number===definition.number);
    const graphics=pdfSource.pages.find(p=>p.number===definition.number);
    const scale=source.ctm[0];
    if(source.ctm[1]||source.ctm[2]||source.ctm[4]||source.ctm[5]||Math.abs(source.ctm[3]-scale)>.00001)
      throw new Error('This profile requires an unrotated PDF page transform.');
    const shapes=graphics.shapes.map(s=>({...s,rect:s.rect.map(v=>v*scale),segments:s.segments.map(l=>l.map(v=>v*scale)),lineWidth:s.lineWidth*scale}));
    const glyphs=addUnderlines(source.glyphs.filter(g=>!config.omitFonts.includes(g.sourceFont||g.font)&&visible(g)),shapes);
    const frequencies=new Map();
    for(const g of glyphs.filter(g=>g.text.trim())){
      const size=Number(g.size.toFixed(3));frequencies.set(size,(frequencies.get(size)||0)+1);
    }
    const baseSize=[...frequencies].sort((a,b)=>b[1]-a[1])[0]?.[0];
    if(!baseSize)throw new Error('Page has no retained text from which to infer a body size.');
    const chapter={id:definition.id,navTitle:definition.navTitle,sourcePage:definition.number,baseSize,blocks:[]};
    for(const [index,region] of definition.regions.entries()) {
      const rect=region.rect.map(v=>v*scale*72/config.referenceDpi);
      const content=glyphs.filter(g=>inside(g.x+g.advance/2,g.y-g.size*.35,rect));
      let block;
      if(region.kind==='heading') {
        const bg=backdrop(shapes,rect);
        block={kind:'heading',glyphs:rowsOf(content).flatMap(r=>withSpaces(r.glyphs)),background:bg?.fill,rounded:bg?.curved};
      } else if(region.kind==='conversation') {
        const turns=[];
        for(const row of rowsOf(content)) {
          const line=withSpaces(row.glyphs),colon=line.findIndex(g=>/[：:]/.test(g.text));
          if(colon>=0)turns.push({speaker:line.slice(0,colon+1),lines:[trimmed(line.slice(colon+1))]});
          else if(turns.length)turns.at(-1).lines.push(trimmed(line));
          else throw new Error('Conversation has no speaker boundary.');
        }
        block={kind:'conversation',turns};
      } else if(region.kind==='panel')block=inferPanel(content,shapes,rect,baseSize);
      else if(region.kind==='paragraph') {
        const boxes=shapes.filter(s=>s.stroke&&!s.curved&&s.segments.length>=4&&inside(...center(s.rect),rect)&&s.rect[3]-s.rect[1]>baseSize*.7);
        const rows=rowsOf(content).map(row=>{
          const blanks=boxes.filter(s=>row.y>=s.rect[1]&&row.y<=s.rect[3]+baseSize*.3);
          const line=row.glyphs.filter(g=>g.text.trim()||!blanks.some(s=>inside(g.x+g.advance/2,g.y-g.size*.35,s.rect)));
          for(const blank of blanks)line.push({kind:'blank',text:' ',x:blank.rect[0],y:row.y,
            advance:blank.rect[2]-blank.rect[0],size:baseSize,widthEm:(blank.rect[2]-blank.rect[0])/baseSize});
          return withSpaces(line.sort((a,b)=>a.x-b.x));
        });
        block={kind:'paragraph',rows,boxes:boxes.map(s=>s.rect)};
      } else if(['figure','diagram'].includes(region.kind)) {
        const crop=cropBackground(source,rect,workDir,assets,`p${definition.number}-${index}.png`);
        block={kind:region.kind,alt:region.alt,asset:crop.asset,width:crop.rect[2]-crop.rect[0],height:crop.rect[3]-crop.rect[1],sourceRect:crop.rect};
        if(region.kind==='diagram')block.labels=inferLabels(content,crop.rect);
      } else throw new Error(`Unknown region kind: ${region.kind}`);
      chapter.blocks.push({...block,id:`${definition.id}-${index}`,source:{page:definition.number,rect}});
    }
    chapters.push(chapter);
  }
  return {model:{schemaVersion:1,title:config.title,source:{pdfSha256:pdfSource.sha256,htmlSha256:htmlSource.sha256},
    profile:{regionSelection:'explicit',cellGrouping:'inferred',labelGrouping:'inferred',omittedFonts:config.omitFonts},
    fonts:htmlSource.fonts,chapters},assets};
}

module.exports={buildModel,inside,area,center,near,isWhite,visible,rowsOf,trimmed,withSpaces,addUnderlines,backdrop,mergeIntervals,cropBackground,inferLabels};
