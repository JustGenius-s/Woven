#!/usr/bin/env python3
"""Copy an official Tadoku electronic PDF for in-app PDF rendering.

The reader opens the official file. This script only stores per-page
original text for the catalog and AI. It does not rewrite the story
or add study notes.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_ROOT = PROJECT_ROOT / "entry/src/main/resources/rawfile/reader"
READING_JSON = PROJECT_ROOT / "entry/src/main/resources/rawfile/reading.json"

BODY_SIZE_MIN = 24


def _load_fitz() -> Any:
    sys.path.insert(0, str(PROJECT_ROOT / ".cache/pydeps"))
    import fitz

    return fitz


def _is_page_number(item: dict[str, Any], page_height: float) -> bool:
    if item["y0"] > page_height - 22:
        return True
    font = item["font"]
    return item["size"] < 18 and ("Arial" in font or "Gothic" in font)


def _body_lines(page: Any) -> list[str]:
    page_height = float(page.rect.height)
    chars: list[dict[str, Any]] = []
    for block in page.get_text("rawdict")["blocks"]:
        if block.get("type") == 1:
            continue
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                size = float(span.get("size", 0))
                font = str(span.get("font", ""))
                if size < BODY_SIZE_MIN:
                    continue
                for char in span.get("chars", []):
                    glyph = char.get("c", "")
                    bbox = char["bbox"]
                    item = {
                        "c": glyph,
                        "font": font,
                        "size": size,
                        "x0": bbox[0],
                        "y0": bbox[1],
                    }
                    if _is_page_number(item, page_height):
                        continue
                    chars.append(item)
    if not chars:
        return []
    ordered = sorted(chars, key=lambda item: (round(item["y0"], 0), item["x0"]))
    lines: list[str] = []
    current = ""
    current_y: float | None = None
    for item in ordered:
        if current_y is None or abs(item["y0"] - current_y) < 10:
            current += item["c"]
            if current_y is None:
                current_y = item["y0"]
            continue
        if current:
            lines.append(current)
        current = item["c"]
        current_y = item["y0"]
    if current:
        lines.append(current)
    return lines


def _write_story_pdf(
    pdf: Path,
    dest: Path,
    start: int,
    end: int,
    page_count: int,
    fitz: Any,
) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if start == 1 and end == page_count:
        shutil.copy2(pdf, dest)
        return
    source = fitz.open(pdf)
    output = fitz.open()
    output.insert_pdf(source, from_page=start - 1, to_page=end - 1)
    output.save(dest, deflate=True, garbage=4)
    output.close()
    source.close()


def _update_reading_json(book_id: str, pdf_file: str, passages: list[dict[str, Any]]) -> None:
    works = json.loads(READING_JSON.read_text(encoding="utf-8"))
    for index, work in enumerate(works):
        if work.get("id") == book_id:
            updated = dict(work)
            updated["format"] = "pdf"
            updated["pdfFile"] = pdf_file
            updated.pop("pageImages", None)
            updated["complete"] = True
            updated["passages"] = passages
            works[index] = updated
            break
    else:
        raise SystemExit(f"{book_id} is not in reading.json")
    READING_JSON.write_text(
        json.dumps(works, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", type=Path, help="Official Tadoku electronic PDF")
    parser.add_argument("book_id", help="App id, e.g. tadoku-40280")
    parser.add_argument("--start-page", type=int, default=1,
                        help="1-based first page to keep (default: the official first page)")
    parser.add_argument("--end-page", type=int, default=0,
                        help="1-based last page; 0 means until the last official page")
    args = parser.parse_args()

    fitz = _load_fitz()
    pdf = args.pdf.expanduser().resolve()
    if not pdf.is_file():
        raise SystemExit(f"PDF not found: {pdf}")

    doc = fitz.open(pdf)
    start = max(1, args.start_page)
    end = args.end_page if args.end_page > 0 else doc.page_count
    if start > end or end > doc.page_count:
        raise SystemExit(f"Page range {start}-{end} is outside 1-{doc.page_count}")

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    leftover_dir = OUTPUT_ROOT / args.book_id
    if leftover_dir.is_dir():
        for leftover in leftover_dir.glob("p*.jpg"):
            leftover.unlink()
        for leftover in leftover_dir.glob("art*.jpg"):
            leftover.unlink()

    dest = OUTPUT_ROOT / f"{args.book_id}.pdf"
    _write_story_pdf(pdf, dest, start, end, doc.page_count, fitz)
    pdf_file = f"reader/{args.book_id}.pdf"
    print(f"{pdf_file} {dest.stat().st_size} pages={end - start + 1}")

    passages: list[dict[str, Any]] = []
    for index, page_number in enumerate(range(start, end + 1), start=1):
        text = "\n".join(_body_lines(doc[page_number - 1]))
        passages.append({
            "title": str(index),
            "text": text,
            "note": "",
        })
        print(f"{args.book_id} p{index:02d} {text.replace(chr(10), ' / ')!r}")

    _update_reading_json(args.book_id, pdf_file, passages)


if __name__ == "__main__":
    main()
