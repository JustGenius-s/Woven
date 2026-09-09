// Local figure coordinates keep every annotation attached to its source image.
// When larger type no longer fits, reserve lanes outside the image and connect
// the relocated labels to their original anchors. No PDF page offsets survive.
(() => {
  const dataElement=document.getElementById('diagram-data');
  const data=dataElement?JSON.parse(dataElement.textContent):(window.WovenChapter?.diagrams||[]);
  const reading=document.getElementById('reading');
  const NS='http://www.w3.org/2000/svg';
  const node=(name,attributes={},text)=>{const el=document.createElementNS(NS,name);for(const [k,v] of Object.entries(attributes))el.setAttribute(k,v);if(text!==undefined)el.textContent=text;return el;};
  const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
  const overlap=(a,b,gap)=>a[0]<b[2]+gap&&a[2]>b[0]-gap&&a[1]<b[3]+gap&&a[3]>b[1]-gap;

  function labelItem(label,scale,available) {
    let glyphs=label.glyphs.map(g=>({...g,x:g.x-label.anchor[0],y:g.y-label.anchor[1]}));
    let bounds=[label.bounds[0]-label.anchor[0],label.bounds[1]-label.anchor[1],label.bounds[2]-label.anchor[0],label.bounds[3]-label.anchor[1]];
    if((bounds[2]-bounds[0])*scale>available) {
      const limit=available/scale,lines=[[]];let advance=0;
      for(const g of label.glyphs){if(advance+g.advance>limit&&lines.at(-1).length){lines.push([]);advance=0;}lines.at(-1).push({...g,x:advance});advance+=g.advance;}
      const lineHeight=Math.max(...glyphs.map(g=>g.size))*1.4;
      const width=Math.max(...lines.map(line=>line.at(-1).x+line.at(-1).advance));
      glyphs=lines.flatMap((line,i)=>line.map(g=>({...g,x:g.x-width/2,y:i*lineHeight})));
      bounds=[-width/2,Math.min(...glyphs.map(g=>g.y-g.size*g.ascent)),width/2,Math.max(...glyphs.map(g=>g.y+g.size*g.descent))];
    }
    if(label.box){const pad=label.box.padding;bounds=[bounds[0]-pad,bounds[1]-pad,bounds[2]+pad,bounds[3]+pad];}
    bounds=bounds.map(v=>v*scale);
    return {label,glyphs,scale,bounds,width:bounds[2]-bounds[0],height:bounds[3]-bounds[1]};
  }

  function layout(diagram) {
    const figure=document.getElementById(diagram.id);if(!figure)return;
    const svg=figure.querySelector('svg');
    const width=figure.clientWidth;if(!width)return;
    const fontSize=parseFloat(getComputedStyle(reading).fontSize),imageScale=width/diagram.width;
    const labelScale=fontSize/diagram.baseSize/imageScale;
    const gap=Math.max(6,fontSize*.5/imageScale),margin=gap*.5;
    const items=diagram.labels.map(label=>labelItem(label,labelScale,diagram.width-2*margin));
    const originalBoxes=items.map(item=>[item.label.anchor[0]+item.bounds[0],item.label.anchor[1]+item.bounds[1],item.label.anchor[0]+item.bounds[2],item.label.anchor[1]+item.bounds[3]]);
    const dock=labelScale>1.35||originalBoxes.some((box,i)=>box[0]<0||box[2]>diagram.width||box[1]<0||box[3]>diagram.height||originalBoxes.slice(i+1).some(other=>overlap(box,other,gap*.2)));
    let imageY=0,totalHeight=diagram.height;
    if(dock) {
      const pack=side=>{
        const rows=[];
        for(const item of items.filter(i=>i.label.side===side).sort((a,b)=>a.label.anchor[0]-b.label.anchor[0])) {
          let row=rows.at(-1),left=clamp(item.label.anchor[0]-item.width/2,margin,diagram.width-margin-item.width);
          if(!row)rows.push(row={items:[],end:margin-gap,height:0});
          left=Math.max(left,row.end+gap);
          if(left+item.width>diagram.width-margin&&row.items.length){rows.push(row={items:[],end:margin-gap,height:0});left=clamp(item.label.anchor[0]-item.width/2,margin,diagram.width-margin-item.width);}
          row.items.push(item);row.end=left+item.width;row.height=Math.max(row.height,item.height);item.left=left;
        }
        return rows;
      };
      const top=pack('top'),bottom=pack('bottom');
      let cursor=margin;
      for(const row of top){for(const item of row.items)item.top=cursor;cursor+=row.height+gap;}
      imageY=top.length?cursor+gap:0;
      cursor=imageY+diagram.height+gap;
      for(const row of bottom){for(const item of row.items)item.top=cursor;cursor+=row.height+gap;}
      totalHeight=bottom.length?cursor:imageY+diagram.height;
      for(const item of items){item.x=item.left-item.bounds[0];item.y=item.top-item.bounds[1];}
    } else for(const item of items){item.x=item.label.anchor[0];item.y=item.label.anchor[1];}
    svg.setAttribute('viewBox',`0 0 ${diagram.width} ${totalHeight}`);
    figure.dataset.labelPlacement=dock?'connected-lanes':'original-anchors';
    svg.querySelector('.diagram-image').setAttribute('transform',`translate(0 ${imageY})`);
    const leaders=svg.querySelector('.diagram-leaders'),labels=svg.querySelector('.diagram-labels');
    leaders.replaceChildren();labels.replaceChildren();
    for(const item of items) {
      if(dock) {
        const [ax,ay]=item.label.anchor,top=item.label.side==='top';
        const startX=item.left+item.width/2,startY=top?item.top+item.height:item.top;
        const endY=ay+imageY;
        leaders.append(node('path',{d:`M ${startX} ${startY} L ${startX} ${startY+(top?gap/2:-gap/2)} L ${ax} ${endY}`,fill:'none',stroke:item.label.box?.stroke||'#536d63','stroke-width':1/imageScale,'stroke-linecap':'round'}));
        leaders.append(node('circle',{cx:ax,cy:endY,r:2/imageScale,fill:'#536d63'}));
        if(!item.label.box)labels.append(node('rect',{x:item.left-margin*.4,y:item.top-margin*.3,width:item.width+margin*.8,height:item.height+margin*.6,rx:margin*.3,fill:'#fff',stroke:'#bdccc5','stroke-width':.7/imageScale}));
      }
      if(item.label.box)labels.append(node('rect',{x:item.x+item.bounds[0],y:item.y+item.bounds[1],width:item.width,height:item.height,
        fill:item.label.box.fill,stroke:item.label.box.stroke,'stroke-width':1.3/imageScale}));
      const group=node('g',{transform:`translate(${item.x} ${item.y}) scale(${item.scale})`,'aria-label':item.label.text});
      for(const g of item.glyphs) {
        const attributes={x:g.x,y:g.y,'font-family':`source-${g.font}`,'font-size':g.size,fill:g.fill};
        if(g.stroke!=='transparent'&&g.strokeEm)Object.assign(attributes,{stroke:g.stroke,'stroke-width':g.strokeEm*g.size,'paint-order':'stroke fill'});
        group.append(node('text',attributes,g.text));
      }
      labels.append(group);
    }
  }
  let scheduled=false;
  const refresh=()=>{if(scheduled)return;scheduled=true;requestAnimationFrame(()=>{scheduled=false;data.forEach(layout);});};
  document.getElementById('font-size')?.addEventListener('input',event=>{reading.style.fontSize=event.target.value+'px';document.getElementById('font-value').textContent=event.target.value;refresh();});
  document.getElementById('line-height')?.addEventListener('input',event=>{reading.style.lineHeight=event.target.value;document.getElementById('line-value').textContent=event.target.value;});
  window.addEventListener('woven-reader-style',refresh);
  if('ResizeObserver' in window){const observer=new ResizeObserver(refresh);data.forEach(d=>observer.observe(document.getElementById(d.id)));}
  window.addEventListener('resize',refresh);
  document.fonts.ready.then(refresh);
  refresh();
})();
