#!/usr/bin/env python3
"""Generate deterministic EPUB files consumed by HarmonyOS Reader Kit."""

from __future__ import annotations

import json
import zipfile
from html import escape
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
CONTENT_FILE = PROJECT_ROOT / "entry/src/main/resources/rawfile/content/reading.json"
OUTPUT_DIR = PROJECT_ROOT / "entry/src/main/resources/rawfile/reader"
ZIP_DATE = (2025, 1, 1, 0, 0, 0)


def zip_info(path: str, compression: int) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(path, ZIP_DATE)
    info.compress_type = compression
    info.create_system = 3
    info.external_attr = 0o644 << 16
    return info


def write_entry(archive: zipfile.ZipFile, path: str, content: str,
                compression: int = zipfile.ZIP_DEFLATED) -> None:
    archive.writestr(zip_info(path, compression), content.encode("utf-8"))


def chapter_document(work: dict, passage: dict, index: int, total: int) -> str:
    source = ""
    if index == total:
        source = f"""
      <footer class="source">
        <p>{escape(work['sourceName'])}</p>
        <p>{escape(work['rights'])}</p>
      </footer>"""
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja">
  <head>
    <meta charset="utf-8" />
    <title>{escape(work['title'])} · 節選 {index}</title>
    <link rel="stylesheet" type="text/css" href="styles.css" />
  </head>
  <body>
    <main>
      <p class="eyebrow">{escape(work['genre'])} · {escape(work['level'])}</p>
      <h1>{escape(work['title'])}</h1>
      <p class="author">{escape(work['author'])} · {escape(work['titleReading'])}</p>
      <p class="section">節選 {index} / {total}</p>
      <p class="original" lang="ja">{escape(passage['text'])}</p>
      <aside>
        <p class="note-title">学习提示</p>
        <p>{escape(passage['note'])}</p>
      </aside>{source}
    </main>
  </body>
</html>
"""


def build_epub(work: dict, output_path: Path) -> None:
    passages = work["passages"]
    manifest_items = [
        '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
        '<item id="styles" href="styles.css" media-type="text/css"/>',
    ]
    spine_items = []
    nav_items = []
    for index, _ in enumerate(passages, start=1):
        manifest_items.append(
            f'<item id="chapter-{index}" href="chapter-{index}.xhtml" media-type="application/xhtml+xml"/>'
        )
        spine_items.append(f'<itemref idref="chapter-{index}"/>')
        nav_items.append(f'<li><a href="chapter-{index}.xhtml">節選 {index}</a></li>')

    package = f"""<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id" xml:lang="ja">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">urn:kotoba:{escape(work['id'])}</dc:identifier>
    <dc:title>{escape(work['title'])}</dc:title>
    <dc:creator>{escape(work['author'])}</dc:creator>
    <dc:language>ja</dc:language>
    <dc:rights>{escape(work['rights'])}</dc:rights>
    <meta property="dcterms:modified">2025-01-01T00:00:00Z</meta>
  </metadata>
  <manifest>
    {' '.join(manifest_items)}
  </manifest>
  <spine page-progression-direction="ltr">
    {' '.join(spine_items)}
  </spine>
</package>
"""
    navigation = f"""<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">
  <head><meta charset="utf-8"/><title>目录</title></head>
  <body>
    <nav epub:type="toc" id="toc">
      <h1>{escape(work['title'])}</h1>
      <ol>{''.join(nav_items)}</ol>
    </nav>
  </body>
</html>
"""
    styles = """html, body { margin: 0; padding: 0; }
body { font-family: sans-serif; }
main { padding: 1.2em 1.1em 2em; }
.eyebrow { margin: 0 0 0.55em; font-size: 0.72em; letter-spacing: 0.08em; opacity: 0.62; }
h1 { margin: 0; font-size: 1.48em; line-height: 1.25; font-weight: 700; }
.author { margin: 0.45em 0 1.9em; font-size: 0.78em; opacity: 0.68; }
.section { margin: 0 0 1.15em; font-size: 0.72em; letter-spacing: 0.08em; opacity: 0.58; }
.original { margin: 0; font-size: 1.08em; line-height: 1.95; text-align: justify; }
aside { margin-top: 2.2em; padding: 1em 1.05em; border: 1px solid rgba(80, 67, 45, 0.16); border-radius: 0.75em; }
aside p { margin: 0; font-size: 0.76em; line-height: 1.7; opacity: 0.72; }
aside .note-title { margin-bottom: 0.4em; font-weight: 700; opacity: 0.9; }
.source { margin-top: 2em; font-size: 0.64em; line-height: 1.55; opacity: 0.48; }
.source p { margin: 0.25em 0; }
"""
    container = """<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""

    with zipfile.ZipFile(output_path, "w") as archive:
        write_entry(archive, "mimetype", "application/epub+zip", zipfile.ZIP_STORED)
        write_entry(archive, "META-INF/container.xml", container)
        write_entry(archive, "OEBPS/content.opf", package)
        write_entry(archive, "OEBPS/nav.xhtml", navigation)
        write_entry(archive, "OEBPS/styles.css", styles)
        for index, passage in enumerate(passages, start=1):
            write_entry(
                archive,
                f"OEBPS/chapter-{index}.xhtml",
                chapter_document(work, passage, index, len(passages)),
            )


def main() -> None:
    works = json.loads(CONTENT_FILE.read_text(encoding="utf-8"))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for work in works:
        output_path = OUTPUT_DIR / f"{work['id']}.epub"
        build_epub(work, output_path)
        print(f"generated {output_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
