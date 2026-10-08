#!/usr/bin/env python3
"""Build audited Starter lesson reflows; keep the reviewed L01 edition unchanged."""
import argparse,hashlib,html,json,re,sys,zipfile
from pathlib import Path
import fitz
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/lib/irodori'))
from source_fonts import SourceFonts
from starter_layout import StarterPage


def xml_page(title,body):
 return '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml" lang="ja"><head><meta charset="utf-8"/><title>'+html.escape(title)+'</title><link rel="stylesheet" href="style.css"/></head><body>'+body+'</body></html>'

def build(source,lesson,cache,output):
 book_id=f'irodori-a1-l{lesson:02d}-reflow';title='いろどり 入门 · '+(f'第 {lesson} 课' if lesson else '教室用语')
 sha=hashlib.sha256(source.read_bytes()).hexdigest();fonts=SourceFonts(cache/f'fonts-l{lesson:02}',sha,starter_aliases=True)
 doc=fitz.open(source);assets={};pages=[];audits=[]
 for i,page in enumerate(doc,1):
  model=StarterPage(page,i,lesson,fonts,assets);markup,audit=model.layout()
  footer=f'<p class="footer"><span style="font-size:.65em!important;color:#888!important">入門　'+(f'L{lesson} - {i}' if lesson else f'教室のことば - {i}')+'　© The Japan Foundation</span></p>'
  pages.append(xml_page(f'第 {i} 页','<div class="chapter">'+markup+footer+'</div>').encode());audits.append(audit)
  print(f'L{lesson:02} p{i:02}: {audit["bodyCharacters"]} chars, {audit["imageCharacters"]} in graphics, {audit["nativeTables"]} tables',flush=True)
 font_assets,font_css,font_report=fonts.export();files={'style.css':(font_css+'\n'+(ROOT/'scripts/lib/irodori/starter.css').read_text()).encode(),**assets,**font_assets}
 titles=[f'第 {i} 页' for i in range(1,len(pages)+1)]
 for i,data in enumerate(pages,1):files[f'p{i}.xhtml']=data
 files['nav.xhtml']=xml_page('目录','<nav xmlns:epub="http://www.idpf.org/2007/ops" epub:type="toc"><ol>'+''.join(f'<li><a href="p{i}.xhtml">{t}</a></li>' for i,t in enumerate(titles,1))+'</ol></nav>').encode()
 files['toc.ncx']=('<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="'+book_id+'"/></head><docTitle><text>'+title+'</text></docTitle><navMap>'+''.join(f'<navPoint id="p{i}" playOrder="{i}"><navLabel><text>{t}</text></navLabel><content src="p{i}.xhtml"/></navPoint>' for i,t in enumerate(titles,1))+'</navMap></ncx>').encode()
 manifest='<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="css" href="style.css" media-type="text/css"/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
 manifest+=''.join(f'<item id="p{i}" href="p{i}.xhtml" media-type="application/xhtml+xml"/>' for i in range(1,len(pages)+1))
 for i,path in enumerate([*assets,*font_assets]):manifest+=f'<item id="a{i}" href="{path}" media-type="'+('font/ttf' if path.endswith('.ttf') else 'image/png')+'"/>'
 files['content.opf']=('<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">'+book_id+'</dc:identifier><dc:title>'+title+'</dc:title><dc:creator>The Japan Foundation</dc:creator><dc:language>ja</dc:language><dc:rights>© The Japan Foundation</dc:rights><meta property="dcterms:modified">2026-10-08T00:00:00Z</meta></metadata><manifest>'+manifest+'</manifest><spine toc="ncx">'+''.join(f'<itemref idref="p{i}"/>' for i in range(1,len(pages)+1))+'</spine></package>').encode()
 dest=output/f'{book_id}.epub';dest.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(dest,'w') as z:
  def put(name,data,method=zipfile.ZIP_DEFLATED):
   info=zipfile.ZipInfo(name,(2026,10,8,0,0,0));info.compress_type=method;z.writestr(info,data)
  put('mimetype',b'application/epub+zip',zipfile.ZIP_STORED)
  put('META-INF/container.xml',b'<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
  for name,data in files.items():put('OEBPS/'+name,data)
 preview=cache/f'l{lesson:02}'
 for name,data in files.items():
  path=preview/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 digest=hashlib.sha256(dest.read_bytes()).hexdigest()
 record={'lesson':lesson,'lessonId':f'irodori-a1-l{lesson:02}','id':book_id,'title':title,'titles':titles,'fileBytes':dest.stat().st_size,'cache':digest[:12],'pageCount':len(pages),'sourceSha256':sha,'epubSha256':digest,'pages':audits,'fonts':font_report}
 (preview/'audit.json').write_text(json.dumps(record,ensure_ascii=False,indent=2))
 return record

def main():
 ap=argparse.ArgumentParser();ap.add_argument('source',type=Path);ap.add_argument('--lessons',default='0,2-18');ap.add_argument('--cache',type=Path,default=ROOT/'.cache/irodori-starter');ap.add_argument('--output',type=Path,default=ROOT/'.cache/irodori-starter/epubs');a=ap.parse_args()
 lessons=[]
 for v in a.lessons.split(','):
  if '-' in v:
   lo,hi=map(int,v.split('-'));lessons.extend(range(lo,hi+1))
  else:lessons.append(int(v))
 for lesson in lessons:
  if lesson==1:raise ValueError('L01 uses the separately reviewed build-irodori-sample.py pipeline')
  sources=list(a.source.glob(f'X_L{lesson:02}*.pdf')) if lesson else [a.source/'X_kyoshitsu_CN.pdf']
  if len(sources)!=1:raise ValueError(f'Expected one source for L{lesson}: {sources}')
  build(sources[0],lesson,a.cache,a.output)
if __name__=='__main__':main()
