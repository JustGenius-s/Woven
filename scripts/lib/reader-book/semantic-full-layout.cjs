const {PNG}=require('pngjs');
const core=require('./semantic-layout.cjs');
const {inside,center,area,near,isWhite,visible,rowsOf,withSpaces,trimmed,addUnderlines,backdrop,cropBackground,inferLabels}=core;
const {edgesOf,lineLevels,recoverCells,cellBackground,sentenceRows}=require('./semantic-geometry.cjs');
const {renderedGlyphs}=require('./semantic-text-inventory.cjs');
const union=rects=>[Math.min(...rects.map(r=>r[0])),Math.min(...rects.map(r=>r[1])),Math.max(...rects.map(r=>r[2])),Math.max(...rects.map(r=>r[3]))];
const contains=(g,rect)=>inside(g.x+g.advance/2,g.y-g.size*.35,rect);
const intersects=(a,b)=>Math.min(a[2],b[2])>Math.max(a[0],b[0])&&Math.min(a[3],b[3])>Math.max(a[1],b[1]);

// Recover ruby as a text relationship. Small Japanese readings above a larger
// baseline are kept with their base text when a paragraph wraps.
function textRows(glyphs) {
  const rows=rowsOf(glyphs),result=[],readings=new Set();
  for(const small of rows) {
    const base=rows.find(r=>r.y>small.y&&r.y-small.y<r.size*1.2&&r.size>small.size*1.5&&
      r.glyphs.some(g=>small.glyphs.some(s=>s.x<g.x+g.advance&&s.x+s.advance>g.x)));
    if(base) {
      small.isReading=true;
      const parts=[];
      for(const g of small.glyphs){const last=parts.at(-1)?.at(-1);if(!last||g.x-last.x-last.advance>g.size*.8)parts.push([]);parts.at(-1).push(g);}
      for(const glyphs of parts)readings.add({...small,glyphs});
    }
  }
  for(const row of rows.filter(r=>!r.isReading)) {
    let glyphs=[...row.glyphs];
    for(const small of [...readings].filter(r=>r.y<row.y&&row.y-r.y<row.size*1.2)) {
      const left=Math.min(...small.glyphs.map(g=>g.x)),right=Math.max(...small.glyphs.map(g=>g.x+g.advance));
      const base=glyphs.filter(g=>g.kind!=='ruby'&&g.x+g.advance>left-1&&g.x<right+1);
      if(!base.length)continue;
      const first=glyphs.indexOf(base[0]);
      glyphs=glyphs.filter(g=>!base.includes(g));
      glyphs.splice(first,0,{...base[0],kind:'ruby',base,reading:small.glyphs,advance:base.at(-1).x+base.at(-1).advance-base[0].x,text:base.map(g=>g.text).join('')});
      readings.delete(small);
    }
    result.push(withSpaces(glyphs));
  }
  // A reading without a reliably matched base remains live text, never lost.
  for(const row of readings)result.push(withSpaces(row.glyphs));
  return result;
}

function buildFullModel(config,htmlSource,pdfSource,workDir) {
  const assets=new Map(),pageModels=[],audit=[];
  const approved=config.pages.filter(p=>p.regions.some(r=>r.approved));
  const approvedResult=core.buildModel({...config,pages:approved},htmlSource,pdfSource,workDir);
  for(const [name,bytes] of approvedResult.assets)assets.set(name,bytes);
  for(const definition of config.pages) {
    const existing=approvedResult.model.chapters.find(c=>c.sourcePage===definition.number);
    if(existing){pageModels.push(existing);audit.push({page:definition.number,method:'approved-regions',blocks:existing.blocks.length});continue;}
    const source=htmlSource.pages.find(p=>p.number===definition.number),graphics=pdfSource.pages.find(p=>p.number===definition.number);
    if(!source||!graphics)throw new Error(`Missing source page ${definition.number}`);
    const scale=source.ctm[0],factor=scale*72/config.referenceDpi,base=26.448;
    const convert=rect=>rect.map(v=>v*factor);
    const shapes=graphics.shapes.map(s=>({...s,rect:s.rect.map(v=>v*scale),segments:s.segments.map(l=>l.map(v=>v*scale)),lineWidth:s.lineWidth*scale}));
    const pictures=graphics.images.map((i,index)=>({rect:i.rect.map(v=>v*scale),index}));
    const excluded=g=>config.omitFonts.includes(g.sourceFont||g.font)||!visible(g)||
      ((g.sourceFont||g.font)==='ff3'&&/[A-Za-z]/.test(g.text))||
      (definition.number===1&&/[A-Za-z]/.test(g.text))||
      g.y-g.size*.35>1102*factor||g.y<35*factor;
    const glyphs=addUnderlines(source.glyphs.filter(g=>!excluded(g)).map((g,index)=>({...g,sourceIndex:index})),shapes);
    const used=new Set(),usedPictures=new Set(),blocks=[];
    let sequence=0;
    const consume=gs=>{gs.forEach(g=>used.add(g.sourceIndex));return gs;};
    const select=(rect,all=false)=>glyphs.filter(g=>(all||!used.has(g.sourceIndex))&&contains(g,rect));
    const id=()=>`p${definition.number}-b${++sequence}`;
    const selectedPictures=rect=>pictures.filter(p=>inside(...center(p.rect),rect)&&area(p.rect)>8);
    const push=(block,rect)=>{block.id||=id();block.source={page:definition.number,rect};blocks.push(block);return block;};

    function art(rect,content=[],options={}) {
      const crop=cropBackground(source,rect,workDir,assets,`full-p${definition.number}-${sequence++}.png`);
      selectedPictures(rect).forEach(p=>usedPictures.add(p.index));
      const labels=inferLabels(content,crop.rect);
      return {kind:labels.length?'diagram':'figure',id:id(),asset:crop.asset,alt:content.map(g=>g.text).join('')||'挿絵',
        width:crop.rect[2]-crop.rect[0],height:crop.rect[3]-crop.rect[1],sourceRect:crop.rect,...(labels.length?{labels}:{}),...options};
    }

    function paragraph(content,rect,options={}) {
      const boxShapes=shapes.filter(s=>s.stroke&&!isWhite(s.stroke)&&!s.curved&&s.segments.length>=4&&inside(...center(s.rect),rect)&&
        s.rect[3]-s.rect[1]>base*.6&&s.rect[3]-s.rect[1]<base*2.5);
      const rows=textRows(content);
      for(const shape of boxShapes) {
        if(content.some(g=>g.text.trim()&&contains(g,shape.rect)))continue;
        const nearest=rows.find(row=>row.some(g=>g.y>=shape.rect[1]&&g.y<=shape.rect[3]+base*.4));
        const blank={kind:'blank',text:' ',x:shape.rect[0],y:nearest?.[0]?.y||shape.rect[3],advance:shape.rect[2]-shape.rect[0],size:base,widthEm:(shape.rect[2]-shape.rect[0])/base};
        if(nearest){nearest.push(blank);nearest.sort((a,b)=>a.x-b.x);}else rows.push([blank]);
      }
      const writingLines=options.writing?lineLevels(edgesOf(shapes,rect,s=>s.stroke&&!isWhite(s.stroke)))
        .filter(l=>l.intervals.some(r=>r[1]-r[0]>base*5)).map(l=>({y:l.at,widthEm:Math.max(...l.intervals.map(r=>r[1]-r[0]))/base})):[];
      if(writingLines.length)for(const line of writingLines){const row=rows.find(row=>row.some(g=>line.y>=g.y&&line.y-g.y<base*1.5));if(row)row.push({kind:'rule',widthEm:line.widthEm});else rows.push([{kind:'rule',widthEm:line.widthEm}]);}
      return {kind:'paragraph',rows,...options};
    }

    function panel(rect,content) {
      const bg=backdrop(shapes,rect);
      if(!bg)throw new Error(`Page ${definition.number}: missing panel background`);
      const edges=edgesOf(shapes,bg.rect,s=>s.stroke&&isWhite(s.stroke));
      const cells=recoverCells(shapes,bg.rect,s=>s.stroke&&isWhite(s.stroke),base*.5);
      const assigned=new Set(),rows=sentenceRows(cells).map(row=>{
        const groups=[];
        for(const cell of row.cells) {
          const gs=content.filter(g=>contains(g,cell.rect));gs.forEach(g=>assigned.add(g));
          const divider=edges.find(e=>e.dash.length&&near(e.l[0],e.l[2],1)&&e.l[0]>cell.rect[0]+4&&e.l[0]<cell.rect[2]-4&&
            Math.min(e.l[1],e.l[3])>=cell.rect[1]-3&&Math.max(e.l[1],e.l[3])<=cell.rect[3]+3);
          const value={rect:cell.rect,rows:textRows(gs),...(divider?{slot:{widthEm:(cell.rect[2]-divider.l[0])/base}}:{})};
          const last=groups.at(-1);
          if(last&&near(last.rect[2],cell.rect[0],5)&&near(last.rect[1],cell.rect[1],4)&&near(last.rect[3],cell.rect[3],4)){last.cells.push(value);last.rect[2]=cell.rect[2];}
          else groups.push({rect:[...cell.rect],cells:[value]});
        }
        return {top:row.top,bottom:row.bottom,groups,outside:[]};
      });
      for(const row of rowsOf(content.filter(g=>!assigned.has(g)&&g.text.trim()))) {
        let sentence=rows.find(r=>row.y>=r.top-base*.2&&row.y<=r.bottom+base*.3);
        if(!sentence){sentence={top:row.y-base,bottom:row.y,groups:[],outside:[]};rows.push(sentence);}
        sentence.outside.push(...withSpaces(row.glyphs));
      }
      rows.sort((a,b)=>a.top-b.top);
      return {kind:'multi-panel',background:bg.fill,rounded:bg.curved,dashed:edges.some(e=>e.dash.length&&Math.max(...e.dash)>4),rows};
    }

    function buildTable(rect,content,options={}) {
      let cells=recoverCells(shapes,rect,s=>s.stroke&&!isWhite(s.stroke),base*.35);
      if(!cells.length)throw new Error(`Page ${definition.number}: no source table cells in ${rect.map(v=>Math.round(v/factor))}`);
      const xs=[...new Set(cells.flatMap(c=>[c.rect[0],c.rect[2]]).map(v=>Math.round(v*10)/10))].sort((a,b)=>a-b);
      const ys=[...new Set(cells.flatMap(c=>[c.rect[1],c.rect[3]]).map(v=>Math.round(v*10)/10))].sort((a,b)=>a-b);
      const nearest=(value,levels)=>levels.reduce((best,v,i)=>Math.abs(v-value)<Math.abs(levels[best]-value)?i:best,0);
      const assigned=new Set();
      for(const cell of cells) {
        cell.col=nearest(cell.rect[0],xs);cell.colSpan=nearest(cell.rect[2],xs)-cell.col;
        cell.row=nearest(cell.rect[1],ys);cell.rowSpan=nearest(cell.rect[3],ys)-cell.row;
        cell.glyphs=content.filter(g=>contains(g,cell.rect));cell.glyphs.forEach(g=>assigned.add(g));
        cell.rows=textRows(cell.glyphs);cell.background=cellBackground(shapes,cell.rect);
      }
      const outside=content.filter(g=>!assigned.has(g)&&g.text.trim());
      if(outside.length)throw new Error(`Page ${definition.number}: table region has text outside recovered cells: ${outside.map(g=>g.text).join('')}`);
      let columns=xs.length-1;
      if(options.removeEmptyColumns) {
        const retained=Array.from({length:columns},(_,i)=>i).filter(i=>cells.some(c=>c.col===i&&c.glyphs.some(g=>g.text.trim())));
        cells=cells.flatMap(c=>{
          const covered=retained.filter(i=>i>=c.col&&i<c.col+c.colSpan);
          return covered.length?[{...c,col:retained.indexOf(covered[0]),colSpan:covered.length}]:[];
        });columns=retained.length;
      }
      const tableRows=Array.from({length:ys.length-1},(_,row)=>{
        const entries=cells.filter(c=>c.row===row);
        for(let col=0;col<columns;col++)if(!cells.some(c=>c.row<=row&&c.row+c.rowSpan>row&&c.col<=col&&c.col+c.colSpan>col))
          entries.push({col,row,colSpan:1,rowSpan:1,rows:[],background:undefined});
        return entries.sort((a,b)=>a.col-b.col);
      });
      return {kind:'table',columns,rows:tableRows,
        borderColor:cells[0]?.borderColor||'#707b7b',writing:!!options.writing,compact:!!options.compact,calendar:!!options.calendar,
        widthEm:(rect[2]-rect[0])/base};
    }

    function cards(region,rect,content) {
      const xs=Array.isArray(region.xs[0])?region.xs:region.xs.slice(0,-1).map((x,i)=>[x,region.xs[i+1]]);
      const items=[];
      for(let ri=0;ri<region.ys.length-1;ri++)for(let ci=0;ci<xs.length;ci++) {
        if(region.count!==undefined&&items.length>=region.count)continue;
        const cell=convert([xs[ci][0],region.ys[ri],xs[ci][1],region.ys[ri+1]]);
        const gs=content.filter(g=>contains(g,cell));
        let picture;
        if(region.diagrams)picture=art(cell,gs);
        else {
          const pics=selectedPictures(cell);
          const selected=pics.filter(p=>p.rect[2]-p.rect[0]>base*.4&&p.rect[3]-p.rect[1]>base*.4);
          if(selected.length) {
            const pr=union(selected.map(p=>p.rect));
            const clipped=[Math.max(cell[0]+1,pr[0]-1),Math.max(cell[1]+1,pr[1]-1),Math.min(cell[2]-1,pr[2]+1),Math.min(cell[3]-1,pr[3]+1)];
            const labels=gs.filter(g=>contains(g,clipped));
            picture=art(clipped,labels);picture.embedded=labels.map(g=>g.sourceIndex);
          }
        }
        const free=region.diagrams?[]:gs.filter(g=>!picture?.embedded?.includes(g.sourceIndex));
        const before=free.filter(g=>!picture||g.y-g.size*.35<(picture.sourceRect[1]+picture.sourceRect[3])/2);
        const after=free.filter(g=>!before.includes(g));
        const cellEdges=edgesOf(shapes,cell,s=>s.stroke&&!isWhite(s.stroke));
        const border=region.border?(cellEdges.find(e=>Math.hypot(e.l[2]-e.l[0],e.l[3]-e.l[1])>(cell[2]-cell[0])*.6)?.color||'#707b7b'):undefined;
        items.push({id:id(),rect:cell,before:textRows(before),after:textRows(after),picture,border,background:cellBackground(shapes,cell)});
      }
      // The original art scale is shared across every cell; adding captions or
      // larger type changes card height, not the illustration's aspect ratio.
      const artwork=items.filter(i=>i.picture);
      const frameWidth=Math.max(base,...artwork.map(i=>i.picture.width)),frameHeight=Math.max(base,...artwork.map(i=>i.picture.height));
      for(const item of artwork){item.frameWidth=frameWidth;item.frameHeight=frameHeight;}
      const widthEm=(rect[2]-rect[0])/base;
      return {kind:'cards',items,columns:xs.length,widthEm,cardWidthEm:(widthEm-.6*(xs.length-1))/xs.length-.005};
    }

    function imageRow(rect,content,options={}) {
      const picRects=options.imageRects?.map(convert)||selectedPictures(rect).map(p=>p.rect);
      const picturesForRow=picRects.map(r=>art(r,content.filter(g=>contains(g,r))));
      const text=content.filter(g=>!picRects.some(r=>contains(g,r)));
      if(options.split) {
        const split=options.split*factor;
        const number=text.filter(g=>g.x<160*factor);
        return {kind:'paired-row',number:textRows(number),items:[
          {rows:textRows(text.filter(g=>g.x>=160*factor&&g.x<split)),pictures:picturesForRow.filter(p=>center(p.sourceRect)[0]<split)},
          {rows:textRows(text.filter(g=>g.x>=split)),pictures:picturesForRow.filter(p=>center(p.sourceRect)[0]>=split)}]};
      }
      return {kind:'image-row',rows:paragraph(text,rect,options).rows,pictures:picturesForRow,routine:!!options.routine};
    }

    function greeting(region,rect,content) {
      const split=region.sceneLeft*factor,portraitRight=region.portraitRight*factor;
      const portraitPics=selectedPictures(rect).filter(p=>center(p.rect)[0]<portraitRight);
      const scenePics=selectedPictures(rect).filter(p=>center(p.rect)[0]>=split);
      const sceneRect=scenePics.length?union(scenePics.map(p=>p.rect)):null;
      const sceneLabels=sceneRect?content.filter(g=>contains(g,sceneRect)):[];
      const scene=sceneRect?art(sceneRect,sceneLabels):undefined;
      const text=content.filter(g=>!sceneLabels.includes(g));
      const lines=rowsOf(text),turns=[];
      for(const pic of portraitPics.sort((a,b)=>a.rect[1]-b.rect[1])) {
        const y=center(pic.rect)[1];
        const assigned=lines.filter(line=>Math.abs(line.y-y)<=Math.min(...portraitPics.map(other=>Math.abs(line.y-center(other.rect)[1])))+.1);
        turns.push({rows:assigned.map(r=>withSpaces(r.glyphs)),picture:art(pic.rect,[])});
      }
      if(!turns.length)turns.push({rows:textRows(text)});
      return {kind:'greeting',turns,scene};
    }

    const definitions=definition.regions.map(r=>({...r,cssRect:convert(r.rect)}));
    // Complex illustrated units own their text first, before nearby prose is
    // joined into a conversation. No nearest-Y image/text matching is used.
    const priority=r=>r.kind==='conversation'?3:r.kind==='figure'?2:1;
    for(const region of [...definitions].sort((a,b)=>priority(a)-priority(b))) {
      const rect=region.cssRect;
      let content=select(rect),block;
      if(region.kind==='conversation') {
        // A long source line may extend past a nearby illustration column.
        // Keep its complete baseline after the illustration's labels are owned.
        const baselines=rowsOf(content).map(r=>r.y);
        content=glyphs.filter(g=>!used.has(g.sourceIndex)&&baselines.some(y=>near(y,g.y,Math.max(2,g.size*.28))));
        const turns=[];
        for(const row of rowsOf(content)) {
          const line=withSpaces(row.glyphs),colon=line.findIndex(g=>/[：:]/.test(g.text));
          if(colon>=0)turns.push({speaker:line.slice(0,colon+1),lines:[trimmed(line.slice(colon+1))]});
          else if(turns.length)turns.at(-1).lines.push(line);
          else turns.push({speaker:[],lines:[line]});
        }
        block={kind:'conversation',turns};
      } else if(region.kind==='table')block=buildTable(rect,content,region);
      else if(region.kind==='cards')block=cards(region,rect,content);
      else if(region.kind==='paragraph')block=paragraph(content,rect,region);
      else if(region.kind==='image-row')block=imageRow(rect,content,region);
      else if(region.kind==='greeting')block=greeting(region,rect,content);
      else if(region.kind==='parallel') {
        block={kind:'parallel',items:region.columns.slice(0,-1).map((left,i)=>{
          const cell=[left*factor,rect[1],region.columns[i+1]*factor,rect[3]],split=region.splits[i]*factor;
          const gs=content.filter(g=>contains(g,cell)),rows=rowsOf(gs);
          const contentRows=rows.map(row=>{
            const left=withSpaces(row.glyphs.filter(g=>g.x+g.advance/2<split)),right=withSpaces(row.glyphs.filter(g=>g.x+g.advance/2>=split));
            return {left,right,leftBackground:cellBackground(shapes,[cell[0],row.y-base,split,row.y]),rightBackground:cellBackground(shapes,[split,row.y-base,cell[2],row.y])};
          });
          return {rows:contentRows,border:region.border,borderColor:edgesOf(shapes,cell,s=>s.stroke&&!isWhite(s.stroke))[0]?.color||'#707b7b'};
        })};
      } else if(region.kind==='figure'||region.kind==='diagram') {
        const pics=region.kind==='figure'?selectedPictures(rect):[];
        const artRect=pics.length?union(pics.map(p=>p.rect)):rect;
        content=select(artRect);block=art(artRect,content);
        if(region.kind==='figure')block.scene=true;
      }
      else if(region.kind==='blank-area')block={kind:'blank-area'};
      else if(region.kind==='cover') {
        const kickerRect=convert(region.kicker),kickerGlyphs=content.filter(g=>contains(g,kickerRect));
        const bands=region.bands.map(r=>art(convert(r),[]));
        const publisher=region.publisher?art(convert(region.publisher),content.filter(g=>contains(g,convert(region.publisher)))):undefined;
        block={kind:'cover',background:region.background,bands,kicker:kickerGlyphs.length?{kind:'paragraph',rows:textRows(kickerGlyphs)}:art(kickerRect,[]),publisher};
      } else if(region.kind==='toc') {
        block={kind:'toc',items:region.targets.map((target,i)=>{
          const gs=content.filter(g=>g.y>region.ys[i]*factor&&g.y<region.ys[i+1]*factor);
          return {target,number:gs.filter(g=>g.x<230*factor),rows:textRows(gs.filter(g=>g.x>=230*factor&&g.x<676*factor)),page:gs.filter(g=>g.x>=676*factor)};
        })};
      } else if(region.kind==='colophon')block={kind:'colophon',rows:textRows(content)};
      else if(region.kind==='callout-diagram') {
        const cells=recoverCells(shapes,rect,s=>s.stroke&&!isWhite(s.stroke));
        const boxes=cells.filter(c=>c.rect[1]<region.imageRect[1]*factor&&content.some(g=>contains(g,c.rect)));
        if(!boxes.length)throw new Error(`Page ${definition.number}: expected coloured callout boxes`);
        block=art(rect,[]);block.kind='diagram';
        const crop=block.sourceRect,labels=[],assigned=new Set();
        const pixels=PNG.sync.read(assets.get(block.asset)),sx=pixels.width/block.width,sy=pixels.height/block.height;
        for(const box of boxes) {
          const gs=content.filter(g=>contains(g,box.rect));gs.forEach(g=>assigned.add(g));
          const x0=Math.min(...gs.map(g=>g.x)),x1=Math.max(...gs.map(g=>g.x+g.advance)),y0=Math.min(...gs.map(g=>g.y-g.size*g.ascent)),y1=Math.max(...gs.map(g=>g.y+g.size*g.descent));
          const anchor=[center(box.rect)[0]-crop[0],center(box.rect)[1]-crop[1]];
          labels.push({text:gs.map(g=>g.text).join(''),anchor,side:'top',bounds:[x0-crop[0],y0-crop[1],x1-crop[0],y1-crop[1]],
            glyphs:gs.map(g=>({...g,x:g.x-crop[0],y:g.y-crop[1]})),box:{stroke:box.borderColor,fill:cellBackground(shapes,box.rect)||'#fff',padding:base*.22},
            relation:'coloured-callout-to-timeline'});
          // Replace the old fixed surround with a growing text-bound surround.
          const r=[Math.max(0,Math.floor((box.rect[0]-crop[0]-2)*sx)),Math.max(0,Math.floor((box.rect[1]-crop[1]-2)*sy)),
            Math.min(pixels.width,Math.ceil((box.rect[2]-crop[0]+2)*sx)),Math.min(pixels.height,Math.ceil((box.rect[3]-crop[1]+2)*sy))];
          for(let y=r[1];y<r[3];y++)for(let x=r[0];x<r[2];x++){const i=(y*pixels.width+x)*4;pixels.data[i]=pixels.data[i+1]=pixels.data[i+2]=pixels.data[i+3]=255;}
        }
        assets.set(block.asset,PNG.sync.write(pixels));
        block.labels=[...labels,...inferLabels(content.filter(g=>!assigned.has(g)),crop)];
      } else throw new Error(`Page ${definition.number}: unknown region ${region.kind}`);
      consume(content);push(block,region.kind==='figure'?block.sourceRect:rect);
    }

    // Recover coloured title bands and sentence containers left outside the
    // explicit illustration/table regions. Their geometry and colours are source data.
    for(const shape of shapes.filter(s=>s.fill&&!isWhite(s.fill)&&s.rect[2]-s.rect[0]>250*factor&&s.rect[3]-s.rect[1]>35*factor&&s.rect[3]<1102*factor)
      .sort((a,b)=>a.rect[1]-b.rect[1])) {
      const content=select(shape.rect);
      if(!content.some(g=>g.text.trim()))continue;
      const green=/^#(?:97c4b2|8ec7b1|7fce8b)$/i.test(shape.fill);
      const block=green?panel(shape.rect,content):{kind:'heading',glyphs:rowsOf(content).flatMap(r=>withSpaces(r.glyphs)),background:shape.fill,rounded:shape.curved};
      consume(content);push(block,shape.rect);
    }
    // Remaining ordinary text remains in source reading order. Keeping this
    // explicit residual inventory makes extraction omissions inspectable.
    const residual=rowsOf(glyphs.filter(g=>!used.has(g.sourceIndex)&&g.text.trim()));
    const runs=[];
    for(const row of residual) {
      let run=runs.at(-1);
      if(!run||row.y-run.at(-1).y>base*2.1||blocks.some(b=>b.source.rect[1]>run.at(-1).y&&b.source.rect[3]<row.y))runs.push(run=[]);
      run.push(row);
    }
    for(const run of runs) {
      const content=run.flatMap(r=>r.glyphs),rect=[Math.min(...content.map(g=>g.x)),Math.min(...content.map(g=>g.y-g.size)),Math.max(...content.map(g=>g.x+g.advance)),Math.max(...content.map(g=>g.y+g.size*.2))];
      consume(content);push(paragraph(content,rect),rect);
    }
    const missing= pictures.filter(p=>!usedPictures.has(p.index)&&area(p.rect)>base*base&&p.rect[1]<1100*factor&&p.rect[3]>70*factor);
    for(const pic of missing) {
      // The cover intentionally uses separate Japanese title bands, leaving
      // the source's baked-in roman-reading strips out of the book.
      if([1,3].includes(definition.number))continue;
      push(art(pic.rect,[]),pic.rect);
    }
    for(const block of [...blocks].filter(b=>b.scene)) {
      const sceneRect=block.source.rect;
      const nearby=blocks.filter(b=>b.kind==='conversation'&&sceneRect[1]<b.source.rect[3]+base*.8&&sceneRect[3]>b.source.rect[1])
        .sort((a,b)=>Math.abs(a.source.rect[3]-sceneRect[1])-Math.abs(b.source.rect[3]-sceneRect[1]))[0];
      if(nearby){(nearby.figures||=[]).push(block);blocks.splice(blocks.indexOf(block),1);}
    }
    blocks.sort((a,b)=>a.source.rect[1]-b.source.rect[1]||a.source.rect[0]-b.source.rect[0]);
    const references=renderedGlyphs(blocks),rendered=new Map();
    for(const g of references)rendered.set(g.sourceIndex,(rendered.get(g.sourceIndex)||0)+1);
    const omitted=glyphs.filter(g=>g.text.trim()&&!rendered.has(g.sourceIndex));
    const duplicated=glyphs.filter(g=>g.text.trim()&&rendered.get(g.sourceIndex)>1);
    if(omitted.length||duplicated.length)throw new Error(`Page ${definition.number}: text ownership: omitted ${omitted.map(g=>g.text).join('')}; repeated ${duplicated.map(g=>g.text).join('')}`);
    pageModels.push({id:definition.id,sourcePage:definition.number,baseSize:base,blocks});
    audit.push({page:definition.number,retainedGlyphs:glyphs.filter(g=>g.text.trim()).length,
      assignedGlyphs:glyphs.filter(g=>g.text.trim()&&used.has(g.sourceIndex)).length,blocks:blocks.length,
      ordinaryText:residual.map(r=>({y:Math.round(r.y/factor),text:r.glyphs.map(g=>g.text).join('')})),
      additionalImages:missing.map(p=>p.rect.map(v=>Math.round(v/factor)))});
  }
  const chapters=config.chapters.map(c=>({...c,baseSize:26.448,blocks:c.pages.map(number=>{
    const p=pageModels.find(p=>p.sourcePage===number);
    if(!p)throw new Error(`Chapter ${c.id}: missing page ${number}`);
    return {kind:'source-section',id:`source-page-${number}`,sourcePage:number,baseSize:p.baseSize,blocks:p.blocks};
  })}));
  return {model:{schemaVersion:2,title:config.title,source:{pdfSha256:pdfSource.sha256,htmlSha256:htmlSource.sha256},
    profile:{regionSelection:'explicit',text:'source-glyphs',fonts:'embedded-width-preserved',cellGrouping:'source-edges',labelGrouping:'attached-to-figure',omittedFonts:config.omitFonts},fonts:htmlSource.fonts,chapters},assets,audit};
}

module.exports={buildFullModel,textRows};
