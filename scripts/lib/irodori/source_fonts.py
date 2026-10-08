"""Repair PDF.js private cmap entries and export native-reader TrueType subsets."""
import io
import json
from collections import defaultdict
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable
from fontTools import subset

class SourceFonts:
    def __init__(self, directory, expected_hash, starter_aliases=False):
        manifest=json.loads((directory/'fonts.json').read_text())
        if manifest['sourceSha256'] != expected_hash:
            raise ValueError('Font cache belongs to another PDF; rerun extract-fonts.cjs')
        self.faces=[];self.lookup=defaultdict(list);self.used=set();self.matched=0
        for record in manifest['fonts']:
            face=TTFont(directory/record['file'],recalcTimestamp=False)
            old=face.getBestCmap(); cmap={}
            for unicode,private in record['glyphs'].items():
                if private not in old and chr(int(unicode)).isspace():continue
                if private not in old:raise ValueError(f"Missing repaired glyph {record['name']} {unicode}")
                cmap[int(unicode)]=old[private]
            # PDF subset glyphs sometimes use XML-forbidden C0 codes. Alias the
            # exact original glyph into the PUA for XHTML, without changing shape.
            for code,glyph in list(cmap.items()):
                if code<32 and code not in (9,10,13):cmap[0xe000+code]=glyph
            # Adobe/Japanese PDFs disagree across extractors on wave-dash Unicode.
            # Both spellings point to this source font's same original outline.
            if starter_aliases and 0x301c in cmap and 0xff5e not in cmap:cmap[0xff5e]=cmap[0x301c]
            if starter_aliases and 0xff5e in cmap and 0x301c not in cmap:cmap[0x301c]=cmap[0xff5e]
            record['cmap']=cmap;record['font']=face
            record['family']='irodori-'+record['id'].replace('_','-')
            self.faces.append(record);self.lookup[record['name']].append(record)
    def family(self, name, text):
        records=self.lookup[name]
        code=ord(text)
        for record in records:
            if code in record['cmap']:
                self.used.add(record['id']);self.matched+=1
                return record['family']
        if text.isspace():return 'sans-serif'
        raise ValueError(f'No source font glyph for {name}: {text!r} U+{code:04X}')
    def export(self):
        assets={};css=[];report=[]
        for record in self.faces:
            if record['id'] not in self.used:continue
            face=record['font'];cmap=record['cmap'];name=record['family']
            if 'CFF ' in face:
                glyphset=face.getGlyphSet();glyphs={}
                for glyphname in face.getGlyphOrder():
                    pen=TTGlyphPen(glyphset)
                    glyphset[glyphname].draw(Cu2QuPen(pen,max_err=0.5,reverse_direction=True))
                    glyphs[glyphname]=pen.glyph()
                fb=FontBuilder(face['head'].unitsPerEm,isTTF=True)
                fb.setupGlyphOrder(face.getGlyphOrder());fb.setupCharacterMap(cmap)
                fb.setupGlyf(glyphs);fb.setupHorizontalMetrics(face['hmtx'].metrics)
                fb.setupHorizontalHeader(ascent=face['hhea'].ascent,descent=face['hhea'].descent,lineGap=face['hhea'].lineGap)
                fb.setupNameTable({'familyName':name,'styleName':'Regular','uniqueFontIdentifier':name,'fullName':name,'psName':name})
                original=face['OS/2']
                fb.setupOS2(sTypoAscender=original.sTypoAscender,sTypoDescender=original.sTypoDescender,
                    sTypoLineGap=original.sTypoLineGap,usWinAscent=original.usWinAscent,usWinDescent=original.usWinDescent,
                    fsType=original.fsType,usWeightClass=original.usWeightClass)
                fb.setupPost();fb.setupMaxp();face=fb.font
            else:
                table=CmapSubtable.newSubtable(4);table.platformID=3;table.platEncID=1;table.language=0;table.cmap={k:v for k,v in cmap.items() if k<=0xffff}
                face['cmap'].tables=[table]
                if any(k>0xffff for k in cmap):
                    full=CmapSubtable.newSubtable(12);full.platformID=3;full.platEncID=10;full.language=0;full.cmap=cmap
                    face['cmap'].tables.append(full)
                for n in face['name'].names:
                    if n.nameID in (1,4,6,16):n.string=name.encode(n.getEncoding())
            options=subset.Options();options.recalc_timestamp=False
            worker=subset.Subsetter(options=options);worker.populate(unicodes=cmap);worker.subset(face)
            face.recalcTimestamp=False
            face['head'].created=face['head'].modified=3874262400
            output=io.BytesIO();face.save(output)
            filename=f'fonts/{record["id"]}.ttf';assets[filename]=output.getvalue()
            # Reload to audit the packaged font, not only our input mapping.
            check=TTFont(io.BytesIO(assets[filename]));assert set(cmap)<=set(check.getBestCmap())
            # Reader Kit parses a format() suffix into the URL on this device.
            # A plain src:url(...) is valid CSS and works in both engines.
            css.append(f'@font-face{{font-family:{name};src:url({filename});font-weight:normal;font-style:normal}}')
            report.append({'family':name,'source':record['name'],'glyphs':len(cmap),'bytes':len(assets[filename])})
        return assets,'\n'.join(css),report
