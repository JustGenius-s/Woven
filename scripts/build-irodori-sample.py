#!/usr/bin/env python3
"""Build the complete Starter L01 reflow; coordinates are PDF points, not screen pixels.
Requires PyMuPDF and fontTools. All lesson text is extracted, never regenerated or translated.
"""
import argparse, hashlib, html, json, re, zipfile
from collections import Counter
from xml.etree import ElementTree as ET
from pathlib import Path
import fitz
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent/"lib"/"irodori"))
from source_fonts import SourceFonts
from lesson_layouts import remaining_page, PAGE_TITLES

ROOT = Path(__file__).resolve().parents[1]
BOOK_ID = 'irodori-a1-l01-sample'
TITLES = ['第 1 页 · こんにちは', '第 2 页 · 听力练习', '第 3 页 · 会话练习'] + PAGE_TITLES
CSS = (ROOT/'scripts/lib/irodori/book.css').read_text()

SOUND_ICON = '<img class="sound-icon" style="width:.8em!important;height:.8em!important;display:inline!important" src="images/sound.png" width="28" height="28" alt=""/>'

def esc(s): return html.escape(s, quote=True)
def source_style(c,base,cls=""):
    # The source font already contains its actual stroke weight; avoid synthetic bold.
    weight='normal'
    background="background:#e5007f;padding:0 .15em;" if c["color"]==16777215 and cls not in ('band','subhead') else ""
    return background+f"font-family:{c['face']}!important;font-size:{c['size']/base:.4f}em!important;color:#{c['color']:06x}!important;font-weight:{weight}!important"

def cjk(c): return '\u3400' <= c <= '\u9fff' or c in '々ヶ'

class Page:
    def __init__(self, page, number, assets, fonts):
        self.page, self.number, self.assets = page, number, assets
        self.chars=[]; self.used={}; self.ruby_count=0; self.track_ids=[]
        for block in page.get_text('rawdict')['blocks']:
            for line in block.get('lines',[]):
                for span in line['spans']:
                    start=len(self.chars)
                    for char in span['chars']:
                        self.chars.append(dict(char, size=span['size'], font=span['font'], color=span['color'], id=len(self.chars), face=fonts.family(span['font'],char['c'])))
                    if re.fullmatch(r'\d{2}-\d{2}', ''.join(c['c'] for c in span['chars']).strip()):
                        self.track_ids.append(set(range(start,len(self.chars))))
    def select(self, rect, label):
        x0,y0,x1,y1=rect
        chars=[c for c in self.chars if x0 <= (c['bbox'][0]+c['bbox'][2])/2 < x1 and y0 <= (c['bbox'][1]+c['bbox'][3])/2 < y1]
        for c in chars:
            if c['id'] in self.used: raise ValueError(f"p{self.number}: duplicate {c['c']} in {label} / {self.used[c['id']]}")
            self.used[c['id']]=label
        return chars
    def picture(self, rect, name):
        chars=self.select(rect, 'image:'+name)
        path='images/'+name+'.png'
        self.assets[path]=self.page.get_pixmap(matrix=fitz.Matrix(2,2),clip=fitz.Rect(rect),alpha=False).tobytes('png')
        alt=''.join(c['c'] for c in chars).strip() or '教材插图'
        width=round((rect[2]-rect[0])*2);height=round((rect[3]-rect[1])*2)
        return f'<img class="banner" src="{path}" width="{width}" height="{height}" alt="{esc(alt)}"/>'
    def text(self, rect, cls='', ruby=True, inline_audio=False, base_size=10.3, flow=False):
        chars=self.select(rect, 'text:'+str(rect))
        ids={c['id'] for c in chars}
        track_sets=[ts for ts in self.track_ids if ts <= ids]
        track_chars=[c for c in chars if any(c['id'] in ts for ts in track_sets)]
        audio_parts=[]
        if track_chars and not inline_audio:
            first_x=min(c['bbox'][0] for c in track_chars)
            audio_parts=[c for c in chars if c in track_chars or (c['c'] in '／/～' and c['bbox'][0]>first_x)]
            chars=[c for c in chars if c not in audio_parts]
        readings=[c for c in chars if ruby and c['size'] <= 6.6 and '\u3040' <= c['c'] <= '\u30ff']
        base=[c for c in chars if c not in readings]
        lines=[]
        for c in sorted(base,key=lambda c:(round(c['origin'][1],1),c['origin'][0])):
            # Small inline Chinese glosses sit about two points above Japanese.
            tolerance=3 if self.number>3 else 1.6
            line=next((l for l in lines if abs(l[0]['origin'][1]-c['origin'][1])<tolerance),None)
            if line is None:lines.append([c])
            else:line.append(c)
        groups=[]
        for c in sorted(readings,key=lambda c:(round(c['origin'][1]),c['bbox'][0])):
            if groups and abs(groups[-1][-1]['origin'][1]-c['origin'][1])<1 and -0.5 <= c['bbox'][0]-groups[-1][-1]['bbox'][2]<3:
                groups[-1].append(c)
            else:groups.append([c])
        if cls in ('band','exercise-label','script-label'):
            lines=[sorted(base,key=lambda c:c['bbox'][0])]
        annotations={}
        for group in groups:
            ry=group[0]['origin'][1]; x0=group[0]['bbox'][0];x1=group[-1]['bbox'][2]
            candidates=[l for l in lines if 1 < l[0]['origin'][1]-ry < 14 and
                        any(cjk(c['c']) and x0-1.5 <= (c['bbox'][0]+c['bbox'][2])/2 <= x1+1.5 for c in l)]
            if not candidates:raise ValueError(f'Unattached ruby p{self.number}: {group}')
            line=min(candidates,key=lambda l:abs(l[0]['origin'][1]-ry-7))
            targets=[c for c in line if cjk(c['c']) and x0-1.5 <= (c['bbox'][0]+c['bbox'][2])/2 <= x1+1.5]
            if not targets:raise ValueError(f'Unattached ruby p{self.number}: {group}')
            first=targets[0]['id'];annotations[first]=(targets,group);self.ruby_count+=1
        # A superscript note marker belongs to the kana cell, not a separate row.
        for line in list(lines):
            markers=[c for c in line if c['c']=='＊']
            if markers and len(markers)==len(line):
                candidates=[l for l in lines if l is not line and any('\u3040' <= c['c'] <= '\u30ff' for c in l)]
                if candidates:
                    target=min(candidates,key=lambda l:abs(l[0]['origin'][1]-line[0]['origin'][1]))
                    target.extend(markers);lines.remove(line)
        suppressed={c['id'] for ts,_ in annotations.values() for c in ts[1:]}
        result=[]
        for line in lines:
            line.sort(key=lambda c:c['bbox'][0]); plain=''.join(c['c'] for c in line).strip()
            if not plain:continue
            lang='zh' if any('SansGB' in c['font'] or 'Song' in c['font'] for c in line) else ('roman' if re.fullmatch(r'[\x00-\x7f\s]+',plain) and not re.search(r'\d\d-\d\d',plain) else '')
            out=[]
            starts={min(ts) for ts in track_sets} if inline_audio else set()
            ends={max(ts) for ts in track_sets} if inline_audio else set()
            for c in line:
                if c['id'] in suppressed:continue
                if c['id'] in starts:out.append(SOUND_ICON+'<span class="audio-code">')
                if c['id'] in annotations:
                    ts,reading_chars=annotations[c['id']]
                    reading=''.join('<span style="font-family:'+r['face']+'!important;font-size:.5em!important;color:inherit!important">'+esc(r['c'])+'</span>' for r in reading_chars)
                    style=source_style(c,base_size,cls)
                    out.append('<ruby><span style="'+style+'">'+esc(''.join(t['c'] for t in ts))+'</span><rt>'+reading+'</rt></ruby>')
                else:
                    value=esc(c['c'])
                    out.append('<span style="'+source_style(c,base_size,cls)+'">'+value+'</span>')
                if c['id'] in ends:out.append('</span>')
            markup=re.sub(r'\s{2,}',' ',''.join(out)).strip()
            # Preserve text runs so the reader can keep words and punctuation together.
            adjacent=r'<span style="([^"]+)">([^<>]*)</span><span style="\1">([^<>]*)</span>'
            while re.search(adjacent,markup):
                markup=re.sub(adjacent,lambda m:'<span style="'+m[1]+'">'+m[2]+m[3]+'</span>',markup)
            result.append(f'<p class="{lang}">'+markup+'</p>')
        if audio_parts:
            labels=[]
            for ts in track_sets:
                label=''.join(c['c'] for c in sorted(track_chars,key=lambda c:c['bbox'][0]) if c['id'] in ts).strip()
                face=next(c['face'] for c in track_chars if c['id'] in ts)
                labels.append(SOUND_ICON+'<span class="audio-code" style="font-family:'+face+'!important;font-size:.72em!important;font-weight:normal!important">'+esc(label)+'</span>')
            separators=[c for c in audio_parts if c not in track_chars]
            # Source slashes separate audio alternatives; keep them with the codes.
            ordered=[(min(c['bbox'][0] for c in track_chars if c['id'] in ts),label) for ts,label in zip(track_sets,labels)] + [(c['bbox'][0],esc(c['c'])) for c in separators]
            result.append('<p class="track">'+' '.join(v for _,v in sorted(ordered))+'</p>')
        markup=''.join(result)
        if flow:markup=re.sub(r'</p><p class="[^"]*">','',markup)
        return f'<div class="{cls}">'+markup+'</div>'
    def audit(self, markup):
        # Running page headers/footers are replaced with an explicit source reference.
        body=[c for c in self.chars if  (46 if self.number==1 else 65) < (c['bbox'][1]+c['bbox'][3])/2 < 797 and c['c'].strip()]
        missing=[c for c in body if c['id'] not in self.used]
        if missing:raise ValueError(f"p{self.number} unmapped: "+str([(c['c'],tuple(round(v,1) for v in c['bbox'])) for c in missing]))
        # Audit emitted text too: selecting a character does not prove ruby/HTML
        # serialization preserved it. Image alt text carries original graphic text.
        root=ET.fromstring('<div>'+markup+'</div>')
        rendered=''.join(root.itertext())+''.join(el.get('alt','') for el in root.iter('img') if el.get('alt')!='教材插图')
        expected=Counter(c['c'] for c in self.chars if c['id'] in self.used and c['c'].strip())
        actual=Counter(c for c in rendered if c.strip())
        if expected!=actual:raise ValueError(f'p{self.number}: emitted text differs; missing={expected-actual}; extra={actual-expected}')
        return {'sourcePage':self.number,'bodyCharacters':len(body),'imageCharacters':sum(self.used[c['id']].startswith('image:') for c in body),'rubyGroups':self.ruby_count,'unmapped':0}

def build(pdf, output, preview, font_source):
    doc=fitz.open(pdf);assets={};chapters=[];audits=[]
    assets['images/sound.png']=doc[0].get_pixmap(matrix=fitz.Matrix(3,3),clip=fitz.Rect(191.5,445.5,205.6,459.7),alpha=False).tobytes('png')
    fonts=SourceFonts(font_source,hashlib.sha256(Path(pdf).read_bytes()).hexdigest())
    if len(doc)!=18:raise ValueError('Expected the reviewed 18-page Starter L01 source PDF')
    for n,title in enumerate(TITLES,1):
        p=Page(doc[n-1],n,assets,fonts);t=p.text;parts=[]
        if n==1:
            parts += [p.picture((60,46,490,78),'topic'),p.picture((60,79,542,155),'lesson-title'),'<div class="intro"><table class="intro-table"><tbody><tr><td class="icon">'+p.picture((73,163,110,205),'question-icon')+'</td><td>'+t((111,157,540,210))+'</td></tr></tbody></table></div>',p.picture((62,269,533,318),'section-heading'),'<div class="goal"><table class="goal-table"><tbody><tr><td class="icon">'+p.picture((62,318,110,349),'can-do')+'</td><td>'+t((111,318,540,349))+'</td></tr></tbody></table></div>',t((60,360,540,438),'instruction'),t((60,438,540,480),'instruction')]
            parts[3:5]=['<div class="keep">'+''.join(parts[3:5])+'</div>']
            cards=[]
            for label,textrect,imgrect in [('a',(70,486,250,530),(63.7796,535.2563,199.8438,671.3206)),('b',(280,588,390,635),(225.3544,638.7867,361.4186,774.851)),('c',(417,486,530,530),(395.4331,535.2563,531.4973,671.3206))]:
                cards.append('<td>'+t(textrect,'caption',base_size=14)+p.picture(imgrect,'greeting-'+label)+'</td>')
            parts.append('<table class="cards"><tbody><tr>'+cards[0]+cards[2]+'</tr></tbody></table><div class="center-card"><table class="cards"><tbody><tr>'+cards[1]+'</tr></tbody></table></div>')
        elif n==2:
            parts.append('<div class="header">'+p.picture((28,23,567,63),'p2-header')+'</div>')
            parts.append(t((60,80,540,118),'instruction'))
            rows=[]
            for i,y in enumerate([125,279]):
                cells=[]
                for j,x in enumerate([98,297]):
                    index=i*2+j+1
                    image_y=156.2786 if i==0 else 310.3931
                    image_x=103.9742 if j==0 else 302.5435
                    cells.append('<td>'+t((x,y,x+197,y+28),'exercise-label',inline_audio=True,base_size=14)+p.picture((image_x,image_y,image_x+188.9023,image_y+118.0639),f'exercise-{index}')+'</td>')
                rows.append('<tr>'+''.join(cells)+'</tr>')
            parts.append('<table class="exercise"><tbody>'+''.join(rows)+'</tbody></table>')
            parts.append(t((60,462,540,525),'instruction'))
        elif n==3:
            parts.append('<div class="header">'+p.picture((28,23,567,63),'p3-header')+'</div>')
            parts.append(t((60,80,540,116),'instruction'))
            tail_left=p.picture((99.1,162.4,119.1,177.5),'tail-left')
            tail_right=p.picture((446.6,189.0,467.0,205.4),'tail-right')
            arrow=p.picture((267.2,204.2,298.5,217.3),'dialogue-arrow')
            for y0,y1,a,b in [(118,145,(120,158,250,246),(305,183,435,273)),(289,318,(120,330,250,374),(305,356,435,402)),(417,446,(120,458,250,504),(305,484,435,530))]:
                heading=t((60,y0,540,y1),'instruction')
                def bubble(rect,cls):
                    if y0==118:
                        split=rect[1]+44
                        content=t((rect[0],rect[1],rect[2],split),base_size=15)+t((rect[0],split,rect[2],rect[3]),'variant',base_size=15)
                    else:content=t(rect,base_size=15)
                    box='<td class="'+cls+'">'+content+'</td>'
                    tail='<td class="tail">'+(tail_right if 'reply' in cls else tail_left)+'</td>'
                    inner=(box+tail) if 'reply' in cls else (tail+box)
                    return '<div class="'+('response' if 'reply' in cls else '')+'"><table class="bubble"><tbody><tr>'+inner+'</tr></tbody></table></div>'
                parts.append('<div class="keep">'+heading+'<table class="dialogue-row"><tbody><tr><td class="speech-cell">'+bubble(a,'speech')+'</td><td class="arrow-cell" style="vertical-align:top;padding-top:'+('2.7' if y0==118 else '1.3')+'em">'+arrow+'</td><td class="speech-cell">'+bubble(b,'speech reply')+'</td></tr></tbody></table></div>')
            for y0,y1 in [(555,599),(603,638),(639,680),(682,723)]:parts.append(t((60,y0,540,y1),'instruction'))
        else:
            parts=remaining_page(p)
        audits.append(p.audit(''.join(parts)))
        parts.append(f'<p class="footer"><span style="font-size:.65em!important;color:#888!important">入門　L1 - {n}　© The Japan Foundation</span></p>')
        body='<div class="chapter">'+''.join(parts)+'</div>';chapters.append((n,title,body))
    output.parent.mkdir(parents=True,exist_ok=True);preview.mkdir(parents=True,exist_ok=True)
    def page(title,body):return '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml" lang="ja"><head><meta charset="utf-8"/><title>'+esc(title)+'</title><link rel="stylesheet" href="style.css"/></head><body>'+body+'</body></html>'
    font_assets,font_css,font_report=fonts.export()
    files={'style.css':(font_css+'\n'+CSS).encode(),**assets,**font_assets}
    for n,title,body in chapters:files[f'p{n}.xhtml']=page(title,body).encode()
    nav='<ol>'+''.join(f'<li><a href="p{n}.xhtml">{esc(title)}</a></li>' for n,title,_ in chapters)+'</ol>'
    files['nav.xhtml']=page('目录','<nav xmlns:epub="http://www.idpf.org/2007/ops" epub:type="toc">'+nav+'</nav>').encode()
    manifest=''.join(f'<item id="p{n}" href="p{n}.xhtml" media-type="application/xhtml+xml"/>' for n,_,_ in chapters)+''.join(f'<item id="img{i}" href="{path}" media-type="image/png"/>' for i,path in enumerate(assets))
    manifest+=''.join(f'<item id="font{i}" href="{path}" media-type="font/ttf"/>' for i,path in enumerate(font_assets))
    ncx='<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="'+BOOK_ID+'"/></head><docTitle><text>いろどり 入门 第1课</text></docTitle><navMap>'+''.join(f'<navPoint id="p{n}" playOrder="{i+1}"><navLabel><text>{esc(title)}</text></navLabel><content src="p{n}.xhtml"/></navPoint>' for i,(n,title,_) in enumerate(chapters))+'</navMap></ncx>'
    files['toc.ncx']=ncx.encode()
    files['content.opf']=('''<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">'''+BOOK_ID+'''</dc:identifier><dc:title>いろどり 入门 第1课 · 完整重排版</dc:title><dc:creator>The Japan Foundation</dc:creator><dc:language>ja</dc:language><dc:rights>© The Japan Foundation</dc:rights><meta property="dcterms:modified">2026-10-08T00:00:00Z</meta></metadata><manifest><item id="css" href="style.css" media-type="text/css"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'''+manifest+'</manifest><spine toc="ncx">'+''.join(f'<itemref idref="p{n}"/>' for n,_,_ in chapters)+'</spine></package>').encode()
    with zipfile.ZipFile(output,'w') as z:
        def put(name,data,method=zipfile.ZIP_DEFLATED):
            info=zipfile.ZipInfo(name,(2026,10,8,0,0,0));info.compress_type=method;z.writestr(info,data)
        put('mimetype',b'application/epub+zip',zipfile.ZIP_STORED)
        put('META-INF/container.xml',b'<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
        for name,data in files.items():put('OEBPS/'+name,data)
    for name,data in files.items():
        path=preview/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    digest=hashlib.sha256(output.read_bytes()).hexdigest()[:12]
    report={'sourceSha256':hashlib.sha256(Path(pdf).read_bytes()).hexdigest(),'epubSha256':digest,'pages':audits,'fonts':font_report,'unmappedFontCharacters':0}
    (preview/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    generated=ROOT/'entry/src/main/ets/services/IrodoriSampleContent.ets'
    generated.write_text('// Generated by scripts/build-irodori-sample.py.\n'+f"export const IRODORI_SAMPLE_ID: string = '{BOOK_ID}';\nexport const IRODORI_SAMPLE_BYTES: number = {output.stat().st_size};\nexport const IRODORI_SAMPLE_CACHE: string = '{digest}';\nexport const IRODORI_SAMPLE_TITLES: string[] = "+json.dumps(TITLES,ensure_ascii=False)+';\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('pdf',type=Path);ap.add_argument('--output',type=Path,default=ROOT/f'entry/src/main/resources/rawfile/reader/{BOOK_ID}.epub');ap.add_argument('--preview',type=Path,default=ROOT/'.cache/irodori-sample');ap.add_argument('--font-source',type=Path,default=ROOT/'.cache/irodori-fonts');a=ap.parse_args();build(a.pdf,a.output,a.preview,a.font_source)
