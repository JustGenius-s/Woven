const fs=require('node:fs/promises');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const {readGraphics}=require('./lib/reader-book/pdf-graphics.cjs');
const {buildModel}=require('./lib/reader-book/semantic-layout.cjs');
const {preview}=require('./lib/reader-book/semantic-preview.cjs');

const root=path.resolve(__dirname,'..');
function option(name,fallback){const index=process.argv.indexOf(name);return index>=0?process.argv[index+1]:fallback;}
async function main(){
  const config=JSON.parse(await fs.readFile(path.join(root,'content/reader-semantic-trial/book.json'),'utf8'));
  const pdf=option('--pdf'),python=option('--python','python');
  if(!pdf)throw new Error('Provide --pdf /path/to/original.pdf');
  const workDir=path.join(root,'.cache/reader-semantic-source');
  await fs.mkdir(workDir,{recursive:true});
  execFileSync(python,[path.join(__dirname,'lib/reader-book/import-pdf2htmlex.py'),'--epub',path.join(root,config.fixedEpub),
    '--pages',config.pages.map(p=>p.number).join(','),'--out',workDir],{windowsHide:true,stdio:'pipe'});
  const htmlSource=JSON.parse(await fs.readFile(path.join(workDir,'html-source.json'),'utf8'));
  const pdfSource=await readGraphics(pdf,config.pages.map(p=>p.number),config.pdfSha256);
  await fs.writeFile(path.join(workDir,'pdf-graphics.json'),JSON.stringify(pdfSource,null,2));
  const {model,assets}=buildModel(config,htmlSource,pdfSource,workDir);
  const out=path.join(root,'docs/previews');
  await fs.mkdir(out,{recursive:true});
  const html=preview(model,assets,workDir);
  await fs.writeFile(path.join(out,'reader-semantic-trial.html'),html);
  await fs.writeFile(path.join(out,'reader-semantic-trial.json'),JSON.stringify(model,null,2)+'\n');
  console.log(JSON.stringify({preview:'docs/previews/reader-semantic-trial.html',model:'docs/previews/reader-semantic-trial.json',sourcePages:config.pages.map(p=>p.number),bytes:Buffer.byteLength(html)},null,2));
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
