"""Read the generated pdf2htmlEX dialect without launching a browser.

Positions are measured with the embedded WOFF advances, not a substitute font.
The importer deliberately rejects rotated/nested clipping containers; such input
needs a geometry adapter rather than silently guessed positions.
"""
import argparse
import copy
import hashlib
import io
import json
import re
from pathlib import Path
from zipfile import ZipFile

from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from lxml import etree


def declarations(value):
    return dict((k.strip(), v.strip()) for k, v in
                (part.split(':', 1) for part in value.split(';') if ':' in part))


def number(value, default=0):
    match = re.match(r'[-+\d.]+', str(value or ''))
    return float(match[0]) if match else default


def extract(archive, pages, out):
    out.mkdir(parents=True, exist_ok=True)
    with ZipFile(archive) as zip_file:
        css = zip_file.read('OEBPS/mybook.css').decode('utf-8').split('@media print')[0]
        rules = {}
        for name, body in re.findall(r'\.([\w-]+)\s*\{([^{}]*)\}', css):
            rules.setdefault(name, {}).update(declarations(body))
        fonts = {}
        font_files = {}
        for body in re.findall(r'@font-face\s*\{([^{}]*)\}', css):
            style = declarations(body)
            family = style['font-family'].strip('"\'')
            filename = re.search(r'url\(["\']?([^\)"\']+)', style['src'])[1]
            data = zip_file.read('OEBPS/' + filename)
            font = TTFont(io.BytesIO(data))
            fonts[family] = (font, font.getBestCmap(), font['head'].unitsPerEm)
            font_files[family] = filename
            (out / filename).write_bytes(data)

        def style_for(el, inherited=None):
            style = dict(inherited or {})
            for cls in el.get('class', '').split():
                style.update(rules.get(cls, {}))
            style.update(declarations(el.get('style', '')))
            return style

        result = {'adapter': 'pdf2htmlEX-axis-aligned-v1',
                  'sha256': hashlib.sha256(Path(archive).read_bytes()).hexdigest(),
                  'fonts': font_files,
                  'pages': []}
        for page_number in pages:
            filename = f'OEBPS/mybook{page_number:04d}.xhtml'
            root = etree.fromstring(zip_file.read(filename), etree.XMLParser(resolve_entities=False, no_network=True))
            elements = root.xpath('//*[contains(concat(" ", @class, " "), " pf ")]')
            if len(elements) != 1:
                raise ValueError(f'{filename}: expected one page container')
            pf = elements[0]
            page_style = style_for(pf)
            width, height = number(page_style['width']), number(page_style['height'])
            pi = pf.xpath('.//*[contains(concat(" ", @class, " "), " pi ")]')[0]
            ctm = json.loads(pi.get('data-data'))['ctm']
            glyphs = []
            for el in pf.xpath('.//*[contains(concat(" ", @class, " "), " t ")]'):
                if any('c' in parent.get('class', '').split() for parent in el.iterancestors()):
                    raise ValueError(f'{filename}: nested clipping text needs a geometry adapter')
                style = style_for(el)
                transform = [float(n) for n in re.search(r'matrix\(([^)]+)\)', style['transform'])[1].split(',')]
                a, b, c, d, e, f = transform
                if abs(b) > 1e-7 or abs(c) > 1e-7 or a <= 0 or d <= 0:
                    raise ValueError(f'{filename}: rotated or reflected text needs a geometry adapter')
                x, y = number(style['left']) + e, height - number(style['bottom']) + f
                cursor = 0

                def characters(value, current):
                    nonlocal cursor
                    family = current.get('font-family')
                    if family not in fonts:
                        raise ValueError(f'Missing embedded font: {family}')
                    font, cmap, units = fonts[family]
                    size = number(current['font-size'])
                    stroke_value = current.get('-webkit-text-stroke', '')
                    stroke = re.match(r'([\d.]+)(em|px)\s+(.*)', stroke_value)
                    for char in value or '':
                        glyph_name = cmap.get(ord(char))
                        if glyph_name is None:
                            raise ValueError(f'{filename}: font {family} has no U+{ord(char):04X}')
                        advance = font['hmtx'][glyph_name][0] * size / units
                        spacing = number(current.get('letter-spacing'))
                        if char == ' ':
                            spacing += number(current.get('word-spacing'))
                        painted_family = family
                        if abs(a/d-1) > .00001:
                            painted_family = f'{family}-sx{round(a/d*100000)}'
                            if painted_family not in font_files:
                                # Bake horizontal glyph scaling into a font, so
                                # normal-flow text keeps its true advance width.
                                stretched = copy.deepcopy(font)
                                if 'glyf' not in stretched:
                                    raise ValueError('Stretched CFF text needs an outline adapter')
                                glyph_set = font.getGlyphSet()
                                for name in font.getGlyphOrder():
                                    pen = TTGlyphPen(glyph_set)
                                    glyph_set[name].draw(TransformPen(pen, (a/d,0,0,1,0,0)))
                                    stretched['glyf'][name] = pen.glyph()
                                    advance_width, lsb = font['hmtx'][name]
                                    stretched['hmtx'][name] = (round(advance_width*a/d), round(lsb*a/d))
                                stretched['hhea'].advanceWidthMax = max(w for w, _ in stretched['hmtx'].metrics.values())
                                output_file = painted_family + '.woff'
                                stretched.save(out / output_file)
                                font_files[painted_family] = output_file
                        glyphs.append({'text': char, 'x': x + cursor * a, 'y': y,
                                       'advance': advance * a, 'size': size * d,
                                       'scaleX': a / d, 'font': painted_family, 'sourceFont': family,
                                       'ascent': font['hhea'].ascent / units,
                                       'descent': -font['hhea'].descent / units,
                                       'fill': current.get('color', '#000000'),
                                       'stroke': stroke[3] if stroke else 'transparent',
                                       'strokeEm': float(stroke[1]) / (size if stroke[2] == 'px' else 1) if stroke else 0})
                        cursor += advance + spacing

                def walk(node, inherited):
                    nonlocal cursor
                    current = style_for(node, inherited)
                    if '_' in node.get('class', '').split():
                        cursor += number(current.get('margin-left')) + number(current.get('width'))
                        return
                    characters(node.text, current)
                    for child in node:
                        walk(child, current)
                        characters(child.tail, current)

                walk(el, style)
            # A colored glyph and its outline are often two coincident strings.
            # Merge paint, not text: keeping both would repeat every character.
            merged = []
            buckets = {}
            for glyph in glyphs:
                key = (glyph['text'], glyph['font'], round(glyph['size'], 2), round(glyph['y'], 1))
                candidates = buckets.setdefault(key, [])
                # Offset paint passes can differ by a fraction of a CSS pixel.
                # Limit merging to a tiny fraction of an advance, so adjacent
                # repeated letters remain distinct at every source font size.
                match = next((g for g in candidates if abs(g['x'] - glyph['x']) < min(.65, glyph['advance'] * .08)), None)
                if match:
                    if glyph['fill'] != 'transparent':
                        match['fill'] = glyph['fill']
                    if glyph['stroke'] != 'transparent' and glyph['strokeEm']:
                        match['stroke'], match['strokeEm'] = glyph['stroke'], glyph['strokeEm']
                else:
                    candidates.append(glyph)
                    merged.append(glyph)
            bi = pf.xpath('.//*[contains(concat(" ", @class, " "), " bi ")]')[0]
            bi_style = style_for(bi)
            background = f'page-{page_number}-background.png'
            (out / background).write_bytes(zip_file.read('OEBPS/' + bi.get('src')))
            result['pages'].append({'number': page_number, 'width': width, 'height': height, 'ctm': ctm,
                                    'background': background,
                                    'backgroundBox': [number(bi_style['left']),
                                                      height-number(bi_style['bottom'])-number(bi_style['height']),
                                                      number(bi_style['width']), number(bi_style['height'])],
                                    'glyphs': merged})
        (out / 'html-source.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--epub', required=True)
    parser.add_argument('--pages', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    extract(args.epub, [int(p) for p in args.pages.split(',')], Path(args.out))
