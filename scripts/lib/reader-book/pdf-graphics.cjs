const fs = require('node:fs/promises');
const { pathToFileURL } = require('node:url');
const { createHash } = require('node:crypto');

const multiply = (a,b) => [a[0]*b[0]+a[2]*b[1],a[1]*b[0]+a[3]*b[1],
  a[0]*b[2]+a[2]*b[3],a[1]*b[2]+a[3]*b[3],a[0]*b[4]+a[2]*b[5]+a[4],a[1]*b[4]+a[3]*b[5]+a[5]];
const point = (m,x,y) => [m[0]*x+m[2]*y+m[4],m[1]*x+m[3]*y+m[5]];

// PDF.js supplies transformed paint operations in addition to text. Keep line
// segments and filled outlines as evidence for containers and shared cell edges.
async function readGraphics(pdfPath, numbers, expectedHash) {
  const bytes = await fs.readFile(pdfPath);
  const hash = createHash('sha256').update(bytes).digest('hex');
  if (expectedHash && expectedHash !== hash) throw new Error('The source PDF hash does not match.');
  const pdfjs = await import(pathToFileURL(require.resolve('pdfjs-dist/legacy/build/pdf.mjs')).href);
  const doc = await pdfjs.getDocument({data:new Uint8Array(bytes),verbosity:0}).promise;
  const names = Object.fromEntries(Object.entries(pdfjs.OPS).map(([k,v])=>[v,k]));
  const pages = [];
  try {
    for (const number of numbers) {
      const page = await doc.getPage(number), list = await page.getOperatorList();
      let state = {matrix:[1,0,0,1,0,0],fill:'#000000',stroke:'#000000',lineWidth:1,dash:[]};
      const stack = [], shapes = [], images = [];
      for (let i=0;i<list.fnArray.length;i++) {
        const name=names[list.fnArray[i]], args=list.argsArray[i];
        if(name==='save') stack.push(structuredClone(state));
        else if(name==='restore') state=stack.pop() || state;
        else if(name==='transform') state.matrix=multiply(state.matrix,args);
        else if(name==='paintFormXObjectBegin') {
          stack.push(structuredClone(state));
          if(args[0])state.matrix=multiply(state.matrix,args[0]);
        }
        else if(name==='paintFormXObjectEnd') state=stack.pop()||state;
        else if(name==='paintImageXObject'||name==='paintInlineImageXObject') {
          const corners=[[0,0],[0,1],[1,0],[1,1]].map(p=>point(state.matrix,...p));
          images.push({rect:[Math.min(...corners.map(p=>p[0])),page.view[3]-Math.max(...corners.map(p=>p[1])),
            Math.max(...corners.map(p=>p[0])),page.view[3]-Math.min(...corners.map(p=>p[1]))]});
        }
        else if(name==='setFillRGBColor') state.fill=args[0];
        else if(name==='setStrokeRGBColor') state.stroke=args[0];
        else if(name==='setLineWidth') state.lineWidth=args[0];
        else if(name==='setDash') state.dash=args[0];
        else if(name==='constructPath') {
          const [paint, paths, bounds]=args, paintName=names[paint];
          if(!['stroke','fill','eoFill','fillStroke','eoFillStroke','closeStroke'].includes(paintName)) continue;
          const toPage=(x,y)=>{const p=point(state.matrix,x,y);return [p[0],page.view[3]-p[1]];};
          const corners=[[bounds[0],bounds[1]],[bounds[0],bounds[3]],[bounds[2],bounds[1]],[bounds[2],bounds[3]]].map(p=>toPage(...p));
          const rect=[Math.min(...corners.map(p=>p[0])),Math.min(...corners.map(p=>p[1])),Math.max(...corners.map(p=>p[0])),Math.max(...corners.map(p=>p[1]))];
          const segments=[]; let curved=false;
          for(const path of paths) {
            let current,first;
            for(let j=0;j<path.length;) {
              const command=path[j++];
              if(command===0) current=first=toPage(path[j++],path[j++]);
              else if(command===1){const end=toPage(path[j++],path[j++]);if(current)segments.push([...current,...end]);current=end;}
              else if(command===2){curved=true;j+=4;current=toPage(path[j++],path[j++]);}
              else if(command===3){curved=true;j+=2;current=toPage(path[j++],path[j++]);}
              else if(command===4){if(current&&first)segments.push([...current,...first]);current=first;}
              else throw new Error(`Unsupported PDF path command ${command}`);
            }
          }
          shapes.push({rect,segments,curved,paint:paintName,
            fill:/fill/i.test(paintName)?state.fill:null,stroke:/stroke/i.test(paintName)?state.stroke:null,
            lineWidth:state.lineWidth*Math.hypot(state.matrix[0],state.matrix[1]),dash:[...state.dash]});
        }
      }
      pages.push({number,shapes,images});
    }
    return {sha256:hash,pages};
  } finally {await doc.destroy();}
}
module.exports={readGraphics};
