"""Geometry-based Starter layouts with explicit ownership and emitted-text audits.

Text, ruby, native tables and simple callouts reflow. Complex artwork stays in
local, high-resolution crops. No page screenshot is used as a text fallback.
"""
import html, math, re, json
from pathlib import Path
ART_REGIONS=json.loads((Path(__file__).with_name("starter_art_regions.json")).read_text())
from collections import Counter
from xml.etree import ElementTree as ET
import fitz
from PIL import Image, ImageDraw
def component_rects(mask):
    import numpy as np
    parents=[];bounds=[];previous=[]
    def root(k):
        while parents[k]!=k:
            parents[k]=parents[parents[k]];k=parents[k]
        return k
    for y,row in enumerate(np.array(mask,dtype=np.int8)):
        changes=np.diff(np.pad(row,(1,1)))
        runs=list(zip(np.flatnonzero(changes==1),np.flatnonzero(changes==-1)))
        current=[]
        for start,end in runs:
            matches={root(k) for a,b,k in previous if a<end and b>start}
            if not matches:
                k=len(parents);parents.append(k);bounds.append([int(start),y,int(end),y+1])
            else:
                k=min(matches)
                for other in matches:
                    if other!=k:
                        parents[other]=k;bounds[k]=list(union([bounds[k],bounds[other]]))
                bounds[k]=list(union([bounds[k],[start,y,end,y+1]]))
            current.append((start,end,k))
        previous=current
    return [fitz.Rect(b) for k,b in enumerate(bounds) if root(k)==k]



def area(r):return max(0,r.width)*max(0,r.height)
def esc(s): return html.escape(s, quote=True)
def union(rects):
    rects=list(rects)
    return fitz.Rect(min(r[0] for r in rects),min(r[1] for r in rects),max(r[2] for r in rects),max(r[3] for r in rects))
def center(r):return fitz.Point((r[0]+r[2])/2,(r[1]+r[3])/2)
def inside(r,b):return center(r) in fitz.Rect(b)
def csscolor(rgb):return '#'+''.join(f'{max(0,min(255,round(v*255))):02x}' for v in rgb)
def kana(c):return '\u3040'<=c<='\u30ff'

class StarterPage:
    def __init__(self,page,number,lesson,fonts,assets,starter_specific=True,audit=True):
        self.page=page;self.number=number;self.lesson=lesson;self.fonts=fonts;self.assets=assets
        self.starter_specific=starter_specific;self.audit=audit
        self.chars=[];self.used={};self.raster_glyphs=set();self.ruby_count=0;self.crop_count=0;self.native_tables=0
        # PDF paths can extend far outside a clipping mask (e.g. the Yokohama
        # map). Respect clip scopes so invisible paths cannot absorb nearby prose.
        self.drawings=[];clips={}
        for drawing in page.get_drawings(extended=True):
            level=drawing.get('level',0)
            clips={k:v for k,v in clips.items() if k<level}
            if drawing['type']=='clip':
                clips[level]=drawing['scissor'];continue
            if drawing['type']=='group':continue
            clip=fitz.Rect(page.rect)
            for bounds in clips.values():clip &= bounds
            original=drawing['rect']
            probe=fitz.Rect(original.x0-.1,original.y0-.1,original.x1+.1,original.y1+.1)
            drawing['clip']=clip;drawing['rect']=original&clip
            # Zero-height/width strokes are real table rules, not empty artwork.
            if probe.intersects(clip):self.drawings.append(drawing)
        self.base=8 if any(d['fill'] and min(d['fill'])<.98 and d['rect'].width>550 and d['rect'].height>800 for d in self.drawings) else 10.5
        self.images=[fitz.Rect(i['bbox']) for i in page.get_image_info()]
        for block in page.get_text('rawdict')['blocks']:
            for line in block.get('lines',[]):
                for span in line['spans']:
                    for char in span['chars']:
                        c=dict(char,size=span['size'],font=span['font'],color=span['color'],direction=line['dir'],id=len(self.chars))
                        if ord(c['c'])<32 and c['c'] not in '\t\n\r':c['c']=chr(0xe000+ord(c['c']))
                        self.chars.append(c)
        self.body=fitz.Rect(25,45 if number==1 or lesson==0 else 64,570,797)
        self.bodychars=[c for c in self.chars if inside(c['bbox'],self.body)]
        self.text=''.join(c['c'] for c in self.bodychars)
        self.items=[]

    def claim(self,chars,owner):
        for c in chars:
            if c['id'] in self.used:raise ValueError(f'L{self.lesson} p{self.number} duplicate {c["id"]}')
            self.used[c['id']]=owner
    def available(self,rect=None):
        return [c for c in self.bodychars if c['id'] not in self.used and (rect is None or inside(c['bbox'],rect))]
    def span(self,chars,base=None):
        if base is None:base=self.base
        out=[];last=None
        for c in chars:
            if (not self.starter_specific or 0xe000<=ord(c['c'])<0xe020 or 'Emoji' in c['font']) and not c['c'].isspace() and not any(ord(c['c']) in record['cmap'] for record in self.fonts.lookup[c['font']]):
                # MuPDF exposes certain custom PDF glyphs as control characters
                # while PDF.js assigns another Unicode. Preserve the glyph image.
                self.raster_glyphs.add(c['id'])
                self.crop_count+=1;name=f'images/p{self.number:02d}-glyph-{self.crop_count}.png'
                pix=self.page.get_pixmap(matrix=fitz.Matrix(3,3),clip=fitz.Rect(c['bbox']),alpha=False)
                self.assets[name]=pix.tobytes('png')
                out.append(['',f'<img class="inline-art" style="width:{(c["bbox"][2]-c["bbox"][0])/base:.4f}em!important;height:auto!important" src="{name}" alt="{esc(c["c"])}"/>']);last=None;continue
            family=self.fonts.family(c['font'],c['c'])
            # Latin ligatures are expanded by MuPDF. The source's regular glyphs
            # carry their original outlines; diagram-only Type 3 glyphs are crops.
            color=c['color'];bg='background:#e5007f;' if color==0xffffff else ''
            style=f'font-family:{family}!important;font-size:{c["size"]/base:.4f}em!important;color:#{color:06x}!important;{bg}'
            if out and last==style:out[-1][1]+=c['c']
            else:out.append([style,c['c']]);last=style
        return ''.join(f'<span style="{s}">{esc(re.sub(r"[ \u3000\t]+"," ",t))}</span>' if s else t for s,t in out)

    def tokens(self,chars):
        # Pair complete furigana runs before layout analysis, so whitespace cuts
        # cannot separate readings from their base characters.
        small=[c for c in chars if c['size']<=7.1 and kana(c['c'])]
        groups=[]
        for c in sorted(small,key=lambda c:(round(c['origin'][1],1),c['bbox'][0])):
            if groups and abs(groups[-1][-1]['origin'][1]-c['origin'][1])<.6 and -.5<=c['bbox'][0]-groups[-1][-1]['bbox'][2]<max(4.5,c['size']*.9):
                groups[-1].append(c)
            else:groups.append([c])
        taken=set();tokens=[]
        for g in groups:
            r=union(c['bbox'] for c in g);y=g[0]['origin'][1]
            candidates=[c for c in chars if c['id'] not in taken and c not in g and c['size']>g[0]['size']*1.28 and ('\u3400'<=c['c']<='\u9fff' or c['c'] in '々ヶ')
                and 1.5<c['origin'][1]-y<16 and r.x0-1.7<=(c['bbox'][0]+c['bbox'][2])/2<=r.x1+1.7]
            if not candidates:continue
            baseline=min(candidates,key=lambda c:abs(c['origin'][1]-y-g[0]['size']*1.35))['origin'][1]
            bases=sorted([c for c in candidates if abs(c['origin'][1]-baseline)<1.1],key=lambda c:c['bbox'][0])
            if not bases:continue
            # Never absorb two independently annotated words into one ruby.
            if any(c['id'] in taken for c in g):continue
            used=g+bases;taken.update(c['id'] for c in used);self.ruby_count+=1
            tokens.append({'rect':union(c['bbox'] for c in used),'chars':used,'base':bases,'reading':g,
                           'y':baseline,'size':max(c['size'] for c in bases)})
        for c in chars:
            if c['id'] not in taken:tokens.append({'rect':fitz.Rect(c['bbox']),'chars':[c],'base':[c],'reading':[], 'y':c['origin'][1],'size':c['size']})
        return tokens

    def text_lines(self,tokens):
        lines=[]
        for t in sorted(tokens,key=lambda t:(round(t['y'],1),t['rect'].x0)):
            line=next((l for l in reversed(lines[-4:]) if abs(l[0]['y']-t['y'])<2.8),None)
            if line is None:lines.append([t])
            else:line.append(t)
        result=[]
        for line in lines:
            runs=[]
            for t in sorted(line,key=lambda t:t['rect'].x0):
                if runs and t['rect'].x0-runs[-1][-1]['rect'].x1<28:runs[-1].append(t)
                else:runs.append([t])
            for run in runs:
                if not any(c['c'].strip() for t in run for c in t['chars']):continue
                result.append({'kind':'text','rect':union(t['rect'] for t in run),'tokens':run,
                    'size':max(t['size'] for t in run),'chars':[c for t in run for c in t['chars']]})
        return result

    def line_html(self,item):
        out=[];pending=[]
        for t in item['tokens']:
            if 'html' in t:
                if pending:out.append(self.span(pending));pending=[]
                out.append(t['html']);continue
            if t['reading']:
                if pending:out.append(self.span(pending));pending=[]
                out.append('<ruby>'+self.span(t['base'])+'<rt>'+self.span(t['reading'],base=t['base'][0]['size'])+'</rt></ruby>')
            else:pending.extend(t['base'])
        if pending:out.append(self.span(pending))
        return ''.join(out)

    def text_html(self,chars,flow=False):
        lines=self.text_lines(self.tokens(chars));lines.sort(key=lambda l:(l['rect'].y0,l['rect'].x0))
        return ''.join('<p>'+self.line_html(l)+'</p>' for l in lines)

    def crop(self,rect,chars=None,kind='art'):
        rect=fitz.Rect(rect)&self.body
        if chars is None:chars=self.available(rect)
        if chars:rect=union([rect]+[c['bbox'] for c in chars])
        rect=fitz.Rect(rect.x0-1,rect.y0-1,rect.x1+1,rect.y1+1)&self.page.rect
        self.claim(chars,'image');self.crop_count+=1
        name=f'images/p{self.number:02d}-{self.crop_count:03d}.png'
        pix=self.page.get_pixmap(matrix=fitz.Matrix(2,2),clip=rect,alpha=False)
        self.assets[name]=pix.tobytes('png')
        alt=''.join(c['c'] for c in sorted(chars,key=lambda c:c['id']))
        width=min(100,max(5,rect.width/(2.2 if len(chars)>8 and rect.height>22 else 4.75)))
        markup=f'<div class="figure" style="width:{width:.2f}%;"><img src="{name}" width="{pix.width}" height="{pix.height}" alt="{esc(alt)}"/></div>'
        return {'kind':kind,'rect':rect,'html':markup,'chars':chars}

    def is_frame(self,d):
        r=d['rect']
        return (r.width>440 and r.height>180 and len(d['items'])<25) or (r.width>500 and r.height>400)

    def reviewed_tables(self):
        if not self.starter_specific:return []
        if (self.lesson,self.number) not in ((2,15),(3,20)):return []
        specs=[([71,100,137,174,211,248,285],[173,194.5]+[194.5+i*32.6 for i in range(1,11)]),
            ([328,357,394,431,468,505,542],[173,194.5,227.1,259.7,292.3,324.9,357.5,390.1,422.7]),
            ([71,100,150,224,285],[528,549]+[549+i*32.6 for i in range(1,8)]),
            ([328,357,409,482,542],[528,549,581.6,614.2,646.8,679.1,711.7,744.3])]
        if (self.lesson,self.number)==(3,20):
            table=next(t for t in self.page.find_tables(strategy='lines_strict').tables if t.row_count==20 and t.col_count==10)
            xs=sorted({round(c[0],1) for c in table.cells if c is not None}|{round(c[2],1) for c in table.cells if c is not None})
            ys=sorted({round(c[1],1) for c in table.cells if c is not None}|{round(c[3],1) for c in table.cells if c is not None})
            specs=[(xs[i:i+3],ys) for i in range(0,10,2)]
        regions=[]
        for xs,ys in specs:
            r=fitz.Rect(xs[0],ys[0],xs[-1],ys[-1]);chars=self.available(r);rows=[]
            for y0,y1 in zip(ys,ys[1:]):
                cells=[]
                for x0,x1 in zip(xs,xs[1:]):
                    cc=[c for c in chars if inside(c['bbox'],(x0,y0,x1,y1))]
                    cells.append('<td'+(' class="shade"' if y0==ys[0] or x0==xs[0] else '')+'>'+self.text_html(cc)+'</td>')
                rows.append('<tr>'+''.join(cells)+'</tr>')
            self.claim(chars,'table');self.native_tables+=1;regions.append(r)
            self.items.append({'kind':'table','rect':r,'chars':chars,'html':'<table class="source-table kana"><tbody>'+''.join(rows)+'</tbody></table>'})
        return regions

    def page_headers(self):
        regions=[]
        def graphic(r):
            item=self.crop(r);self.items.append(item);regions.append(item['rect']);return item
        if self.number==1 and self.lesson:
            graphic((60,46,490,78));graphic((60,79,545,155))
            r=fitz.Rect(60,156,545,230);chars=self.available(r)
            if chars:
                self.claim(chars,'text');self.items.append({'kind':'box','rect':r,'chars':chars,'html':'<div class="intro-question">'+self.text_html(chars)+'</div>'});regions.append(r)
            # Running Starter badge is replaced by the book title in the app.
            regions.append(fitz.Rect(490,25,590,78))
        # Separate each section's title banner from the small Can-do description.
        for d in self.drawings:
            r=d['rect'];fill=d['fill']
            if not fill or not (r.width>430 and 20<r.height<60 and r.x0>45 and r.x1<555 and r.y0>80 and min(fill)<.6):continue
            if any(r.intersects(q) for q in regions):continue
            lower=next((q['rect'] for q in self.drawings if q['fill'] and q['fill'][0]>.95 and q['fill'][1]>.9 and .45<q['fill'][2]<.8 and abs(q['rect'].y0-r.y1)<3 and q['rect'].width>430 and 10<q['rect'].height<55),None)
            if lower is None:continue
            graphic(r)
            chars=self.available(lower)
            if not chars:continue
            self.claim(chars,'text');self.items.append({'kind':'goal','rect':fitz.Rect(lower),'chars':chars,'html':'<div class="can-do">'+self.text_html(chars)+'</div>'});regions.append(fitz.Rect(lower))
        return regions

    def vocabulary_cards(self):
        if self.starter_specific and (self.lesson,self.number)==(0,2):
            # The last source label has a different baseline. Use the reviewed
            # grid so card i remains before section 5, not beside its heading.
            cards=[];rects=[];chars=[]
            for top,bottom in [(129,272),(275,419),(421,567)]:
                for left,right in [(60,222),(223,385),(386,523)]:
                    item=self.crop(fitz.Rect(left,top,right,bottom));rects.append(item['rect']);chars+=item['chars']
                    cards.append('<td>'+re.sub(r'width:[0-9.]+%;','width:100%;',item['html'])+'</td>')
            rect=union(rects)
            self.items.append({'kind':'cards','rect':rect,'chars':chars,'html':'<table class="vocabulary"><tbody>'+''.join('<tr>'+''.join(cards[k:k+2])+'</tr>' for k in range(0,9,2))+'</tbody></table>'})
            return [rect]
        # Source vocabulary grids have explicit a./b./c. or circled-number labels.
        # Slice by those anchors, not by disconnected pieces of an illustration.
        special=self.starter_specific and (self.lesson,self.number) in ((2,17),(0,2))
        if not special and 'ことばの準' not in self.text:return []
        anchors=[]
        for block in self.page.get_text('dict')['blocks']:
            for line in block.get('lines',[]):
                text=''.join(s['text'] for s in line['spans']).strip()
                if re.match(r'^[a-n][.．]',text) or (special and re.match(r'^[①-⑤]',text) and line['bbox'][1]<400):
                    anchors.append(fitz.Rect(line['bbox']))
        rows=[]
        for a in sorted(anchors,key=lambda a:(a.y0,a.x0)):
            row=next((r for r in rows if abs(r[0].y0-a.y0)<4),None)
            if row is None:rows.append([a])
            else:row.append(a)
        excluded=[i['rect'] for i in self.items]
        paths=self.graphics(excluded)
        regions=[]
        instruction_tops=[]
        for block in self.page.get_text('dict')['blocks']:
            for line in block.get('lines',[]):
                text=''.join(s['text'] for s in line['spans']).strip()
                if re.match(r'^\(\s*[1-9]\s*\)',text):instruction_tops.append(line['bbox'][1]-5)
        for row in rows:
            if len(row)<2:continue
            row.sort(key=lambda r:r.x0);y=min(r.y0 for r in row)-(2 if self.lesson==0 else 7)
            if any(q.y0<y<q.y1 for q in excluded):continue
            limit=min([r[0].y0-7 for r in rows if r[0].y0>y+15]+[v for v in instruction_tops if v>y+35]+[797])
            cards=[];bounds=[];allchars=[]
            for k,a in enumerate(row):
                inset=2 if special else 9
                left=a.x0-inset;right=row[k+1].x0-inset if k+1<len(row) else min(558,a.x0+(a.x0-row[k-1].x0)-inset)
                cell=fitz.Rect(left,y,right,min(limit,a.y1+170))
                candidates=[r for r in paths if area(r&cell)>350 and r.height>25 and r.width>20 and r.y1>a.y1+20 and r.y0<a.y1+60]
                if not candidates or any(q.width>cell.width*1.35 for q in candidates):break
                bottom=min(limit,max(r.y1 for r in candidates)+(40 if self.starter_specific and (self.lesson,self.number)==(15,10) else 2))
                # Clothing/object names directly below each picture belong to its card.
                captions=[c for c in self.available() if left<=center(c['bbox']).x<right and bottom-2<=c['bbox'][1]<min(limit,bottom+40)]
                if captions:bottom=min(limit,max(bottom,max(c['bbox'][3] for c in captions)+2))
                rect=fitz.Rect(left,y,right,bottom)
                if any(rect.intersects(q) for q in excluded):break
                cards.append(rect);bounds.append(rect)
            else:
                if len(cards)!=len(row):continue
                for rect in cards:allchars.extend(self.available(rect))
                htmlcards=[]
                for rect in cards:
                    item=self.crop(rect);item['html']=re.sub(r'width:[0-9.]+%;','width:100%;',item['html'])
                    htmlcards.append('<td>'+item['html']+'</td>')
                markup='<table class="vocabulary"><tbody>'+''.join('<tr>'+''.join(htmlcards[k:k+2])+'</tr>' for k in range(0,len(htmlcards),2))+'</tbody></table>'
                r=union(bounds);regions.append(r);excluded.append(r)
                self.items.append({'kind':'cards','rect':r,'chars':allchars,'html':markup})
        return regions

    def exercise_panels(self):
        # Exercise artwork often consists of disconnected paths (a face, a speech
        # balloon, its label). Preserve each horizontal scene as one source panel.
        # Culture/prose pages use live text and independent photographs instead.
        if self.base==8:return []
        excluded=[i['rect'] for i in self.items]
        if self.number==1 and self.lesson:excluded.append(fitz.Rect(490,25,590,78))
        shapes=self.graphics(excluded)
        bands=[]
        for r in sorted([r for r in shapes if r.width>25 and r.height>20],key=lambda r:r.y0):
            if any(q.intersects(r) for q in excluded):continue
            if bands and r.y0<=bands[-1].y1+3:bands[-1].include_rect(r)
            else:bands.append(fitz.Rect(r))
        regions=[]
        for r in bands:
            # Simple isolated callouts can reflow without changing relationships.
            if r.width<100 or (r.width<180 and r.height<75):continue
            if any(r.intersects(q) for q in excluded):continue
            lines=self.text_lines(self.tokens(self.available()))
            changed=True
            while changed:
                changed=False
                for line in lines:
                    q=line['rect'];overlap=q&r
                    if not overlap.is_empty and overlap.width>.5 and overlap.height>.5 and not r.contains(q):
                        r.include_rect(q);changed=True
            # Include each label/answer blank at the edge, not individual letters.
            for line in lines:
                q=line['rect']
                if r.x0-20<=q.x0 and q.x1<=r.x1+60 and 0<=r.y0-q.y1<=16:r.include_rect(q)
            if r.width>300:r.x0=min(r.x0,60)
            if any(r.intersects(q) for q in excluded):continue
            item=self.crop(r);item['html']=re.sub(r'width:[0-9.]+%;','width:100%;',item['html'])
            self.items.append(item);regions.append(item['rect']);excluded.append(item['rect'])
        return regions

    def kanji_rows(self):
        # Each source arrow introduces the same word in three original typefaces.
        # Keep a complete comparison row together, stacking source columns.
        pages={3:13,4:17,5:22,6:16,7:23,8:17,9:15,10:18,11:18,12:17,13:22,14:18,15:20,16:21,17:18,18:15}
        if self.starter_specific:
            if pages.get(self.lesson)!=self.number:return []
        elif '漢字' not in self.text or 'ことば' not in self.text:return []
        arrows=[d['rect'] for d in self.drawings if d['fill'] and d['fill'][0]>.99 and .80<d['fill'][2]<.84 and len(d['items'])==5 and 75<d['rect'].width<95 and 40<d['rect'].height<50]
        regions=[]
        for r in sorted(arrows,key=lambda r:(r.y0,r.x0)):
            end=min([q.x0-7 for q in arrows if q.x0>r.x0+100 and abs(q.y0-r.y0)<2]+[540])
            rect=fitz.Rect(r.x0-1,r.y0-1,end,r.y1+1);chars=self.available(rect)
            bases=sorted([c for c in chars if c['bbox'][0]>r.x1 and c['size']>9 and c['c'].strip()],key=lambda c:c['bbox'][0])
            groups=[]
            for c in bases:
                if groups and c['bbox'][0]-groups[-1][-1]['bbox'][2]<15:groups[-1].append(c)
                else:groups.append([c])
            if len(groups)!=3:
                if self.starter_specific:raise ValueError(f'Kanji row needs three faces: L{self.lesson} {len(groups)} at {rect}')
                continue
            cuts=[rect.x0,r.x1]+[(groups[k][-1]['bbox'][2]+groups[k+1][0]['bbox'][0])/2 for k in range(2)]+[rect.x1]
            cells=[]
            for k,(a,b) in enumerate(zip(cuts,cuts[1:])):
                cc=[c for c in chars if a<=center(c['bbox']).x<b]
                cells.append('<td'+(' class="kanji-label"' if k==0 else '')+'>'+self.text_html(cc)+'</td>')
            self.claim(chars,'table');self.native_tables+=1;regions.append(rect)
            cls='kanji-forms long-word' if max(len(g) for g in groups)>=3 else 'kanji-forms'
            self.items.append({'kind':'table','rect':rect,'chars':chars,'html':'<table class="'+cls+'"><tbody><tr>'+''.join(cells)+'</tr></tbody></table>'})
        return regions

    def table_items(self):
        # Use ruled cells only; never infer a table from incidental text alignment.
        paths=[d for d in self.drawings if not self.is_frame(d) and d['rect'].y1>self.body.y0]
        try:tables=self.page.find_tables(clip=self.body,paths=paths,vertical_strategy='lines_strict',horizontal_strategy='lines_strict').tables
        except Exception:tables=[]
        regions=[i['rect'] for i in self.items if i['kind'] in ('table','art')]
        for table in tables:
            r=fitz.Rect(table.bbox)
            if table.row_count<2 or table.col_count<2 or table.col_count>9 or r.height<30:continue
            if any(r.intersects(q) for q in regions):continue
            cells=table.cells
            if self.base==8:
                item=self.crop(r);self.items.append(item);regions.append(item['rect']);continue
            # A speech bubble's dotted separator is not a ruled table.
            if any(d['fill'] and area(d['rect']&r)>area(r)*.75 and any(it[0]=='c' for it in d['items']) for d in paths):continue
            # Artwork inside a form/table must stay intact. A source crop preserves
            # diagrams instead of converting a blank grid and dropping its contents.
            if any(area(im&r)>20 for im in self.images):
                item=self.crop(r);self.items.append(item);regions.append(item['rect']);continue
            complex_paths=[d for d in paths if inside(d['rect'],r) and any(it[0]=='c' for it in d['items']) and len(d['items'])>6 and d['rect'].width<r.width*.8]
            if len(complex_paths)>15:
                item=self.crop(r);self.items.append(item);regions.append(item['rect']);continue
            allchars=self.available(r)
            if not allchars:continue
            rows=[];assigned=set();seen=set()
            xs=sorted({round(c[0],2) for c in cells if c}|{round(c[2],2) for c in cells if c})
            ys=sorted({round(c[1],2) for c in cells if c}|{round(c[3],2) for c in cells if c})
            for y in ys[:-1]:
                values=[]
                for cell in sorted([c for c in cells if c and abs(c[1]-y)<.02],key=lambda c:c[0]):
                    key=tuple(round(v,2) for v in cell)
                    if key in seen:continue
                    seen.add(key)
                    cc=[c for c in allchars if c['id'] not in assigned and inside(c['bbox'],cell)]
                    assigned.update(c['id'] for c in cc)
                    shade=any(d['fill'] and min(d['fill'])<.93 and inside(cell,d['rect']) for d in paths if d['rect'].width>20)
                    colspan=xs.index(round(cell[2],2))-xs.index(round(cell[0],2))
                    rowspan=ys.index(round(cell[3],2))-ys.index(round(cell[1],2))
                    # Table headers contain overprinted audio labels in several
                    # source PDFs. Preserve their visible compositing as one cell.
                    if y==ys[0] and shade:
                        header=self.crop(cell,cc)
                        content=re.sub(r'width:[0-9.]+%;','width:100%;',header['html'])
                    else:content=self.text_html(cc)
                    values.append(f'<td colspan="{colspan}" rowspan="{rowspan}"'+(' class="shade"' if shade else '')+'>'+content+'</td>')
                rows.append('<tr>'+''.join(values)+'</tr>')
            if {c['id'] for c in allchars}!=assigned:continue
            self.claim([c for c in allchars if c['id'] not in self.used],'table');self.native_tables+=1;regions.append(r)
            self.items.append({'kind':'table','rect':r,'chars':allchars,'html':'<table class="source-table"><tbody>'+''.join(rows)+'</tbody></table>'})
        return regions

    def graphics(self,excluded):
        # Connected components of actual local paths/images, after stripping page
        # backgrounds and large decorative frames. Split disconnected rule paths.
        regions=[]
        def add(r,clip=None):
            r=fitz.Rect(r)&self.body
            if clip is not None:r &= clip
            if r.is_empty or any(q.contains(r) for q in excluded):return
            if r.width<.2:r.x0-=.5;r.x1+=.5
            if r.height<.2:r.y0-=.5;r.y1+=.5
            regions.append(r)
        for d in self.drawings:
            r=d['rect']
            if self.is_frame(d) or (r.y0<self.body.y0 and r.height<70) or (r.width<5 and r.height>200):continue
            if d['fill'] and min(d['fill'])>.97 and d['color'] is None:continue
            if all(it[0] in ('l','re') for it in d['items']):
                for it in d['items']:
                    if it[0]=='re':add(it[1],d['clip'])
                    else:
                        # Long horizontal rules separate sections; don't fuse
                        # several listening turns into one artwork block.
                        r=union([(*it[1],*it[1]),(*it[2],*it[2])])
                        if r.width>380 and r.height<1:continue
                        add(r,d['clip'])
            else:add(r,d['clip'])
        for r in self.images:add(r)
        # PDF Type 3 fonts are vector artwork; preserve their original glyphs.
        for c in self.available():
            if c['font'] not in self.fonts.lookup:add(c['bbox'])
        mask=Image.new('1',(600,850));draw=ImageDraw.Draw(mask)
        for r in regions:draw.rectangle((max(0,math.floor(r.x0-1)),max(0,math.floor(r.y0-1)),min(599,math.ceil(r.x1+1)),min(849,math.ceil(r.y1+1))),fill=1)
        for r in excluded:draw.rectangle((math.floor(r.x0-1),math.floor(r.y0-1),math.ceil(r.x1+1),math.ceil(r.y1+1)),fill=0)
        clusters=[]
        for region in component_rects(mask):
            r=region&self.body
            if r.width*r.height>3:clusters.append(r)
        return clusters

    def native_box(self,r):
        if self.base==8:return None
        chars=self.available(r)
        if not chars or r.width<75 or r.height<18:return None
        ds=[d for d in self.drawings if area(d['rect']&r)>20 and not self.is_frame(d)]
        fills=[d for d in ds if d['fill'] and len(d['items'])<=16 and d['rect'].width>r.width*.65 and d['rect'].height>r.height*.6]
        if len(ds)>14 or any(area(im&r)>20 for im in self.images):return None
        if not fills:
            outlines=[d for d in ds if d['color'] and len(d['items'])<=12 and d['rect'].width>r.width*.85 and d['rect'].height>r.height*.85]
            if not outlines:return None
            fill=dict(max(outlines,key=lambda d:area(d['rect'])));fill['fill']=(1,1,1)
        else:fill=max(fills,key=lambda d:area(d['rect']))
        # Section headings and symbols need their original outline artwork.
        if r.height<32 or min(fill['fill'])<.5 or len(chars)<12:return None
        if any(c['font'] not in self.fonts.lookup or abs(c['direction'][1])>.04 for c in chars):return None
        self.claim(chars,'box')
        border=csscolor(fill['color']) if fill['color'] else '#e8ccb6'
        style=f'background:{csscolor(fill["fill"])};border:1px solid {border};'
        width=95 if len(chars)>75 else 78
        side='margin-left:auto;' if r.x0>250 else ''
        return {'kind':'box','rect':r,'chars':chars,'html':f'<div class="source-box" style="{style}width:{width:.1f}%;{side}">'+self.text_html(chars)+'</div>'}

    def layout(self):
        art=self.page_headers()
        for coords in (ART_REGIONS.get(f'{self.lesson}:{self.number}',[]) if self.starter_specific else []):
            rect=fitz.Rect(coords)
            item=self.crop(rect)
            if rect.width>270:item['html']=re.sub(r'width:[0-9.]+%;','width:100%;',item['html'])
            self.items.append(item);art.append(item['rect'])
        art+=self.vocabulary_cards()
        tables=self.kanji_rows()+self.reviewed_tables()+self.table_items()
        art+=self.exercise_panels()
        callouts=[]
        for d in sorted(self.drawings,key=lambda d:area(d['rect'])):
            r=fitz.Rect(d['rect'])
            if self.is_frame(d) or r.y0<self.body.y0 or r.height<20 or r.width<75 or any(r.intersects(q) for q in tables+callouts+art):continue
            r=fitz.Rect(r.x0-1,r.y0-1,r.x1+1,r.y1+1)
            item=self.native_box(r)
            if item:
                self.items.append(item);callouts.append(r)
        clusters=self.graphics(tables+callouts+art)
        # Expand crops to whole text lines/ruby groups if a graphic touches them.
        # This prevents labels clipped at image edges or duplicated as live text.
        remaining=self.tokens(self.available())
        self.ruby_count=0
        for r in clusters:
            changed=True
            while changed:
                changed=False
                for l in remaining:
                    if any(c['id'] in self.used for c in l['chars']):continue
                    lr=l['rect'];inter=r&lr
                    if not inter.is_empty and inter.width>.5 and inter.height>.5 and not r.contains(lr):
                        # A tiny bullet or audio icon beside a long sentence should
                        # remain separate, not absorb the sentence into its crop.
                        if r.width<16 and inter.width<lr.width*.25:continue
                        r.include_rect(lr);changed=True
            # Merge expansion overlaps before claiming text.
        merged=[]
        for r in clusters:
            overlap=[q for q in merged if q.intersects(r)]
            for q in overlap:r.include_rect(q);merged.remove(q)
            merged.append(r)
        for r in merged:
            if not self.available(r) and r.height>r.width*4 and r.width<45:continue
            if not self.available(r) and area(r)<800 and any(fitz.Rect(q.x0-23,q.y0-6,q.x1+23,q.y1+6).intersects(r) for q in callouts):continue
            if any(r.intersects(q) for q in tables):
                # Table outlines already exist natively; suppress adjoining rules.
                if sum(area(r&q) for q in tables)>area(r)*.7:continue
            if not self.available(r) and any(fitz.Rect(q.x0-4,q.y0-4,q.x1+4,q.y1+4).intersects(r) for q in art+tables):continue
            item=self.native_box(r)
            if item is None:item=self.crop(r)
            self.items.append(item)
        lines=self.text_lines(self.tokens(self.available()))
        for l in lines:self.claim(l['chars'],'text')
        # Attach small sound/step markers to their source text line. Keeping them
        # inline avoids shrinking the whole instruction to the icon's pixel size.
        for marker in list(self.items):
            r=marker['rect']
            if marker['kind']!='art' or r.width>90 or r.height>23:continue
            near=[l for l in lines if abs((l['rect'].y0+l['rect'].y1)/2-(r.y0+r.y1)/2)<10
                  and (min(abs(l['rect'].x0-r.x1),abs(r.x0-l['rect'].x1))<35 or l['rect'].x0<r.x0<l['rect'].x1)]
            if not near:continue
            target=min(near,key=lambda l:min(abs(l['rect'].x0-r.x1),abs(r.x0-l['rect'].x1)))
            src=re.search(r'src="([^"]+)"',marker['html'])[1]
            alt=''.join(c['c'] for c in marker['chars'])
            token={'rect':r,'chars':marker['chars'],'base':[],'reading':[],
                   'html':f'<img class="inline-art" style="width:{r.width/10.5:.2f}em!important;height:auto!important" src="{src}" alt="{esc(alt)}"/>'}
            target['tokens'].append(token);target['tokens'].sort(key=lambda t:t['rect'].x0)
            target['rect'].include_rect(r);self.items.remove(marker)
        # Keep image captions with their photograph, not interleaved with prose
        # that wrapped beside it in the source PDF.
        for item in self.items:
            if item['kind']!='art' or item['rect'].width<90 or item['rect'].height<55:continue
            r=item['rect'];captions=[]
            for l in sorted(lines,key=lambda l:l['rect'].y0):
                lr=l['rect']
                if l['size']<=9 and r.x0<=center(lr).x<=r.x1 and lr.width<=r.width*1.1 and -1<=lr.y0-r.y1<14:
                    captions.append(l);r.include_rect(lr)
            for l in captions:
                item['html']+='<div class="caption">'+self.item_html(l)+'</div>';lines.remove(l)
        self.items.extend(self.prose_blocks(lines))
        for first in list(self.items):
            if first not in self.items or first['kind']!='box':continue
            second=next((i for i in self.items if i is not first and i['kind']=='box' and abs(i['rect'].y0-first['rect'].y0)<8 and first['rect'].x1<i['rect'].x0),None)
            if second:
                self.items.remove(first);self.items.remove(second)
                self.items.append({'kind':'dialogue','rect':union([first['rect'],second['rect']]),'chars':first['chars']+second['chars'],
                    'html':'<table class="columns"><tbody><tr><td>'+first['html']+'</td><td>'+second['html']+'</td></tr></tbody></table>'})
        markup=self.arrange(self.items)
        expected=Counter(c['c'] for c in self.bodychars if c['c'].strip())
        if self.audit:
            root=ET.fromstring('<div>'+markup+'</div>')
            actual=Counter(c for c in ''.join(root.itertext())+''.join(e.get('alt','') for e in root.iter('img')) if c.strip())
            missing=[c for c in self.bodychars if c['c'].strip() and c['id'] not in self.used]
            if missing or expected!=actual:raise ValueError(f'L{self.lesson} p{self.number}: missing ownership {missing}; text missing {expected-actual}; extra {actual-expected}')
        audit={'page':self.number,'bodyCharacters':sum(expected.values()),'imageCharacters':sum(1 for c in self.bodychars if c['c'].strip() and (self.used.get(c['id'])=='image' or c['id'] in self.raster_glyphs)),
               'rubyGroups':self.ruby_count,'nativeTables':self.native_tables,'images':self.crop_count,'unmapped':0 if self.audit else None}
        return markup,audit

    def prose_blocks(self,lines):
        blocks=[];others=[]
        for l in sorted(lines,key=lambda l:(l['rect'].y0,l['rect'].x0)):
            plain=''.join(c['c'] for c in l['chars']).strip()
            if l['size']>10 or re.match(r'^[（(①-⑳❶-❿●•▶◆]',plain):others.append(l);continue
            lang=Counter(c['font'] for c in l['chars']).most_common(1)[0][0]
            candidates=[b for b in blocks[-8:] if b['lang']==lang and abs(b['size']-l['size'])<.6 and -2<l['rect'].y0-b['last'].y1<8 and abs(b['rect'].x0-l['rect'].x0)<24]
            if candidates:
                b=min(candidates,key=lambda b:abs(b['rect'].x0-l['rect'].x0));b['rect'].include_rect(l['rect']);b['last']=l['rect'];b['lines'].append(l);b['chars'].extend(l['chars'])
            elif len(plain)<20:others.append(l)
            else:blocks.append({'kind':'prose','rect':fitz.Rect(l['rect']),'last':l['rect'],'size':l['size'],'lang':lang,'lines':[l],'chars':list(l['chars'])})
        for b in blocks:b['html']='<p>'+''.join(self.line_html(l) for l in b['lines'])+'</p>'
        return others+blocks

    def arrange(self,items,depth=0):
        if not items:return ''
        if len(items)==1:return self.item_html(items[0])
        # Recursive whitespace cuts preserve reading order, including columns.
        def cuts(axis):
            spans=sorted((i['rect'][axis],i['rect'][axis+2]) for i in items);end=spans[0][1];gaps=[]
            for a,b in spans[1:]:
                if a>end:gaps.append((a-end,(a+end)/2))
                end=max(end,b)
            return gaps
        hs=sorted(cuts(1),reverse=True);vs=sorted(cuts(0),reverse=True)
        gap,y=hs[0] if hs else (0,0);vgap,x=vs[0] if vs else (0,0)
        if depth<40 and gap>=5 and (gap>=16 or vgap<18):
            top=[i for i in items if i['rect'].y1<=y];bottom=[i for i in items if i not in top]
            return self.arrange(top,depth+1)+self.arrange(bottom,depth+1)
        if depth<40 and vgap>=18:
            left=[i for i in items if i['rect'].x1<=x];right=[i for i in items if i not in left]
            # Stack independent source columns at the available reading width.
            return self.arrange(left,depth+1)+self.arrange(right,depth+1)
        items=sorted(items,key=lambda i:(round(i['rect'].y0/3),i['rect'].x0))
        return ''.join(self.item_html(i) for i in items)

    def item_html(self,item):
        if item['kind']=='text':return '<p>'+self.line_html(item)+'</p>'
        return item['html']
