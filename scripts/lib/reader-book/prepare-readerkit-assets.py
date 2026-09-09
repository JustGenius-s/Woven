"""Export source fonts and self-contained diagram images for the native EPUB.

Ordinary text stays XHTML. Only labels attached to a diagram are painted into
that local image: Reader Kit does not expose the browser layout hooks used by
semantic-diagram.js. This deliberately scales map labels with their map.
"""
import argparse
import json
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image, ImageColor, ImageDraw, ImageFont


def prepare(model, source, output):
    fonts_dir = output / 'fonts'
    fonts_dir.mkdir(parents=True, exist_ok=True)
    families = set()
    blocks = []

    def collect(value):
        if isinstance(value, dict):
            if value.get('kind') in ('diagram', 'cards'):
                blocks.append(value)
            if 'font' in value:
                families.add(value['font'])
            for child in value.values():
                collect(child)
        elif isinstance(value, list):
            for child in value:
                collect(child)

    collect(model['chapters'])
    fonts = {}
    for family in sorted(families):
        font = TTFont(source / model['fonts'][family], recalcTimestamp=False)
        font.flavor = None
        # Distinguish stretched source variants even in engines that use the
        # font's internal family name when resolving an EPUB @font-face rule.
        name = f'source-{family}'
        for record in font['name'].names:
            if record.nameID in (1, 4, 6, 16):
                record.string = name.encode(record.getEncoding())
        filename = f'{family}.ttf'
        font.save(fonts_dir / filename)
        font.close()
        fonts[family] = f'fonts/{filename}'

    diagrams = {}
    face_cache = {}
    for block in blocks:
            if block['kind'] != 'diagram':
                continue
            # A local figure canvas, never a target device/screen size.
            scale = 3
            width = round(block['width'] * scale)
            height = round(block['height'] * scale)
            sx, sy = width / block['width'], height / block['height']
            with Image.open(output / 'images' / block['asset']) as source_image:
                canvas = source_image.convert('RGBA').resize((width, height), Image.Resampling.LANCZOS)
            draw = ImageDraw.Draw(canvas)
            for label in block['labels']:
                if label.get('box'):
                    box = label['box']
                    padding = box.get('padding', 0)
                    x0, y0, x1, y1 = label['bounds']
                    draw.rectangle(((x0 - padding) * sx, (y0 - padding) * sy,
                                    (x1 + padding) * sx, (y1 + padding) * sy),
                                   fill=box['fill'], outline=box['stroke'], width=max(1, round(sy)))
                for glyph in label['glyphs']:
                    size = max(1, round(glyph['size'] * sy))
                    key = (glyph['font'], size)
                    if key not in face_cache:
                        face_cache[key] = ImageFont.truetype(str(output / fonts[key[0]]), size)
                    fill = ImageColor.getcolor(glyph['fill'], 'RGBA') if glyph['fill'] != 'transparent' else (0, 0, 0, 0)
                    stroke = glyph['stroke']
                    stroke_width = round(glyph['strokeEm'] * glyph['size'] * sy / 2) if stroke != 'transparent' else 0
                    draw.text((glyph['x'] * sx, glyph['y'] * sy), glyph['text'], font=face_cache[key],
                              anchor='ls', fill=fill, stroke_width=stroke_width,
                              stroke_fill=ImageColor.getcolor(stroke, 'RGBA') if stroke_width else fill)
                    if glyph.get('underline'):
                        y = (glyph['y'] + glyph['size'] * .13) * sy
                        draw.line((glyph['x'] * sx, y, (glyph['x'] + glyph['advance']) * sx, y),
                                  fill=glyph['underline'], width=max(1, round(glyph['size'] * .065 * sy)))
            filename = f"images/{block['id']}-attached.png"
            canvas.save(output / filename)
            diagrams[block['id']] = filename
    # Pad related cards to their shared source frame. The whole frame then
    # scales with available width, preserving equal illustration heights and
    # centering without CSS Grid, absolute positioning or a device-size rule.
    cards = {}
    for block in blocks:
        if block['kind'] != 'cards':
            continue
        for card in block['items']:
            picture = card.get('picture')
            if not picture:
                continue
            # Keep ordinary artwork at source resolution. Only diagrams need
            # the higher resolution used to paint their live-text labels.
            scale = 3 if picture['kind'] == 'diagram' else 1
            width, height = round(card['frameWidth'] * scale), round(card['frameHeight'] * scale)
            frame = Image.new('RGBA', (width, height), (255, 255, 255, 0))
            asset = diagrams[picture['id']] if picture['kind'] == 'diagram' else f"images/{picture['asset']}"
            with Image.open(output / asset) as source_image:
                art = source_image.convert('RGBA').resize((round(picture['width'] * scale), round(picture['height'] * scale)), Image.Resampling.LANCZOS)
                frame.alpha_composite(art, ((width - art.width) // 2, (height - art.height) // 2))
            filename = f"images/{card['id']}-frame.png"
            frame.save(output / filename)
            cards[card['id']] = filename
    (output / 'prepared.json').write_text(json.dumps({'fonts': fonts, 'diagrams': diagrams, 'cards': cards}), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', required=True, type=Path)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    prepare(json.loads(args.model.read_text(encoding='utf-8')), args.source, args.out)
