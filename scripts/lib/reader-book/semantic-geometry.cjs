// Recover containers from PDF drawing operations. Small gaps at line joins
// are printer stroke caps, not missing borders. Coordinates here are CSS units.
const {inside,center,near,mergeIntervals,area}=require('./semantic-layout.cjs');

function edgesOf(shapes,rect,predicate=s=>s.stroke) {
  return shapes.filter(s=>predicate(s)&&!s.curved).flatMap(s=>s.segments.map(l=>({l,color:s.stroke,dash:s.dash,width:s.lineWidth})))
    .filter(e=>inside((e.l[0]+e.l[2])/2,(e.l[1]+e.l[3])/2,rect,3));
}
function lineLevels(edges,vertical=false,tolerance=3) {
  const result=[];
  for(const e of edges.filter(e=>!e.dash.length&&near(e.l[vertical?0:1],e.l[vertical?2:3],.8))) {
    const position=e.l[vertical?0:1],a=e.l[vertical?1:0],b=e.l[vertical?3:2];
    if(Math.abs(a-b)<5)continue;
    let level=result.find(v=>near(v.at,position,tolerance));
    if(!level)result.push(level={at:position,intervals:[],color:e.color,width:e.width});
    level.intervals.push([Math.min(a,b),Math.max(a,b)]);
  }
  for(const level of result)level.intervals=mergeIntervals(level.intervals,tolerance*2);
  return result.sort((a,b)=>a.at-b.at);
}
const covers=(level,a,b,tolerance=4)=>level.intervals.some(r=>r[0]<=a+tolerance&&r[1]>=b-tolerance);

function recoverCells(shapes,rect,predicate,minHeight=8) {
  const edges=edgesOf(shapes,rect,predicate),hs=lineLevels(edges),vs=lineLevels(edges,true),cells=[];
  for(let top=0;top<hs.length-1;top++)for(let bottom=top+1;bottom<hs.length;bottom++) {
    const y0=hs[top].at,y1=hs[bottom].at;
    if(y1-y0<minHeight)continue;
    const columns=vs.filter(v=>covers(v,y0,y1));
    for(let i=0;i<columns.length-1;i++) {
      const x0=columns[i].at,x1=columns[i+1].at;
      if(x1-x0<8||!covers(hs[top],x0,x1)||!covers(hs[bottom],x0,x1))continue;
      // A full horizontal separator makes two cells, not a spanning cell.
      if(hs.slice(top+1,bottom).some(h=>covers(h,x0,x1)))continue;
      const cell={rect:[x0,y0,x1,y1],borderColor:columns[i].color,lineWidth:columns[i].width};
      if(!cells.some(c=>c.rect.every((v,j)=>near(v,cell.rect[j]))))cells.push(cell);
    }
  }
  return cells.filter(c=>!cells.some(d=>d!==c&&area(d.rect)<area(c.rect)-5&&
    inside(d.rect[0],d.rect[1],c.rect,2)&&inside(d.rect[2],d.rect[3],c.rect,2)))
    .sort((a,b)=>a.rect[1]-b.rect[1]||a.rect[0]-b.rect[0]);
}

function cellBackground(shapes,rect) {
  return shapes.filter(s=>s.fill&&inside(...center(rect),s.rect,1)&&area(s.rect)>=area(rect)*.5)
    .sort((a,b)=>area(a.rect)-area(b.rect))[0]?.fill;
}

function sentenceRows(cells) {
  const rows=[];
  for(const cell of cells) {
    const r=cell.rect;
    let row=rows.find(row=>Math.min(row.bottom,r[3])-Math.max(row.top,r[1])>
      Math.min(row.bottom-row.top,r[3]-r[1])*.55);
    if(!row)rows.push(row={top:r[1],bottom:r[3],cells:[]});
    row.top=Math.min(row.top,r[1]);row.bottom=Math.max(row.bottom,r[3]);row.cells.push(cell);
  }
  for(const row of rows)row.cells.sort((a,b)=>a.rect[0]-b.rect[0]);
  return rows.sort((a,b)=>a.top-b.top);
}

module.exports={edgesOf,lineLevels,covers,recoverCells,cellBackground,sentenceRows};
