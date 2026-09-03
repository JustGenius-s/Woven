#!/usr/bin/env python3
"""Rebuild bundled vocabulary: exam pitches plus graded extra lexicon.

N5–N1 files keep their headwords, levels, meanings and examples; only
`pitches` are refreshed. Words marked common in JMdict but missing from
those exam lists are split by JMdict newspaper/ichi priority:

- 日常: nf01–nf16 or ichi1
- 一般: remaining newspaper bands (nf17–nf48)
- 补遗: editor-common, no newspaper rank
"""

from __future__ import annotations

import gzip
import json
import re
import urllib.request
import zipfile
from collections import OrderedDict, defaultdict
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / 'entry/src/main/resources/rawfile'
VOCAB_DIR = CONTENT / 'vocabulary'
CACHE = ROOT / '.cache/vocab'
LEVELS = ('n5', 'n4', 'n3', 'n2', 'n1')

WADOKU_URL = (
    'https://media.githubusercontent.com/media/WaDoku/WaDokuJT-Data/'
    'master/WaDokuDa.tab'
)
KANJIUM_URL = (
    'https://raw.githubusercontent.com/mifunetoshiro/kanjium/'
    'master/data/source_files/raw/accents.txt'
)
JMDICT_COMMON_URL = (
    'https://github.com/scriptin/jmdict-simplified/releases/download/'
    '3.6.2%2B20260831182826/'
    'jmdict-eng-common-3.6.2+20260831182826.json.zip'
)
JMDICT_XML_URL = 'http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz'
LEXICON_FILES = {
    '日常': 'extra-daily',
    '一般': 'extra-general',
    '补遗': 'extra-supplement',
}

SMALL_FOLLOWERS = set('ゃゅょぁぃぅぇぉャュョァィゥェォ')
USER_AGENT = 'kotoba-harmony-vocab-builder/1.0'


def hira(text: str) -> str:
    chars: list[str] = []
    for char in text:
        code = ord(char)
        if 0x30A1 <= code <= 0x30F6:
            chars.append(chr(code - 0x60))
        else:
            chars.append(char)
    return ''.join(chars)


def split_morae(reading: str) -> list[str]:
    chars = list(hira(reading))
    morae: list[str] = []
    index = 0
    while index < len(chars):
        if index + 1 < len(chars) and chars[index + 1] in SMALL_FOLLOWERS:
            morae.append(chars[index] + chars[index + 1])
            index += 2
        else:
            morae.append(chars[index])
            index += 1
    return morae


def strip_markup(text: str) -> str:
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'\([^)]*\)', ' ', text)
    text = re.sub(r'\[[^\]]*\]', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()


def surface_forms(cell: str) -> list[str]:
    forms: list[str] = []
    seen: set[str] = set()
    for part in re.split(r'[;；]', cell):
        form = strip_markup(part).replace('×', '').replace('*', '').strip()
        if form and form not in seen:
            seen.add(form)
            forms.append(form)
    return forms


def parse_accents(raw: str) -> list[int]:
    accents: list[int] = []
    seen: set[int] = set()
    for part in re.split(r'[,，/／—–-]', raw):
        token = part.strip()
        if token.isdigit():
            value = int(token)
            if value not in seen:
                seen.add(value)
                accents.append(value)
    return accents


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 1024:
        return
    request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        dest.write_bytes(response.read())


def add_index(
    index: dict[tuple[str, str], list[tuple[int, str]]],
    word: str,
    reading: str,
    accents: list[int],
    source: str,
) -> None:
    if not word or not reading or not accents:
        return
    key = (word, reading)
    bucket = index.setdefault(key, [])
    existing = {accent for accent, _source in bucket}
    for accent in accents:
        if accent not in existing:
            bucket.append((accent, source))
            existing.add(accent)


def load_wadoku(path: Path) -> dict[tuple[str, str], list[tuple[int, str]]]:
    index: dict[tuple[str, str], list[tuple[int, str]]] = {}
    with path.open(encoding='utf-8', errors='replace') as handle:
        next(handle, None)
        for line in handle:
            columns = line.rstrip('\n').split('\t')
            if len(columns) < 11 or not columns[10].strip():
                continue
            accents = parse_accents(columns[10])
            if not accents:
                continue
            reading = hira(strip_markup(columns[2]).replace(' ', ''))
            if not reading:
                continue
            forms = surface_forms(columns[1]) + surface_forms(columns[7])
            forms.append(reading)
            for form in forms:
                add_index(index, form, reading, accents, 'wadoku')
                add_index(index, hira(form), reading, accents, 'wadoku')
    return index


def load_kanjium(path: Path) -> dict[tuple[str, str], list[tuple[int, str]]]:
    index: dict[tuple[str, str], list[tuple[int, str]]] = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        parts = line.split('\t')
        if len(parts) < 3:
            continue
        accents = parse_accents(parts[2])
        reading = hira(parts[1])
        add_index(index, parts[0], reading, accents, 'kanjium')
        add_index(index, hira(parts[0]), reading, accents, 'kanjium')
        add_index(index, reading, reading, accents, 'kanjium')
    return index


def lookup(
    word: str,
    reading: str,
    primary: dict[tuple[str, str], list[tuple[int, str]]],
    fallback: dict[tuple[str, str], list[tuple[int, str]]],
) -> list[tuple[int, str]]:
    reading_h = hira(reading)
    keys = (
        (word, reading_h),
        (hira(word), reading_h),
        (reading_h, reading_h),
    )
    for key in keys:
        if key in primary:
            return primary[key]
    for key in keys:
        if key in fallback:
            return fallback[key]
    return []


def to_pitches(reading: str, hits: list[tuple[int, str]]) -> list[dict[str, object]]:
    morae = split_morae(reading)
    pitches: list[dict[str, object]] = []
    seen: set[int] = set()
    for accent, source in hits:
        if accent in seen or accent < 0:
            continue
        seen.add(accent)
        pitches.append({
            'accent': accent,
            'morae': morae,
            'source': source,
        })
    return pitches


def load_common_jmdict(path: Path) -> list[dict[str, object]]:
    with zipfile.ZipFile(path) as archive:
        name = next(item for item in archive.namelist() if item.endswith('.json'))
        payload = json.loads(archive.read(name))
    return list(payload['words'])


def pick_headword(word: dict[str, object]) -> tuple[str, str]:
    kanji = list(word.get('kanji') or [])
    kana = list(word.get('kana') or [])
    if not kana:
        raise ValueError(f"JMdict {word.get('id')} has no reading")
    writing = next((item['text'] for item in kanji if item.get('common')), '')
    if not writing and kanji:
        writing = str(kanji[0]['text'])
    if not writing:
        writing = str(kana[0]['text'])
    if kanji:
        applicable = [
            item for item in kana
            if '*' in (item.get('appliesToKanji') or ['*']) or writing in (item.get('appliesToKanji') or [])
        ]
        preferred = [item for item in applicable if item.get('common')]
        reading = str((preferred or applicable or kana)[0]['text'])
    else:
        preferred = [item for item in kana if item.get('common')]
        reading = str((preferred or kana)[0]['text'])
    return writing, reading


def load_priority(path: Path) -> dict[str, set[str]]:
    index: dict[str, set[str]] = {}
    seq = ''
    tags: set[str] = set()
    with gzip.open(path, mode='rt', encoding='utf-8') as handle:
        for line in handle:
            if '<ent_seq>' in line:
                if seq:
                    index[seq] = tags
                match = re.search(r'<ent_seq>(\d+)</ent_seq>', line)
                seq = match.group(1) if match else ''
                tags = set()
            elif '<ke_pri>' in line or '<re_pri>' in line:
                match = re.search(r'>([^<]+)<', line)
                if match:
                    tags.add(match.group(1))
    if seq:
        index[seq] = tags
    return index


def newspaper_band(tags: set[str]) -> Optional[int]:
    ranks = [int(tag[2:]) for tag in tags if tag.startswith('nf') and tag[2:].isdigit()]
    return min(ranks) if ranks else None


def lexicon_level(tags: set[str]) -> str:
    band = newspaper_band(tags)
    if (band is not None and band <= 16) or 'ichi1' in tags:
        return '日常'
    if band is not None:
        return '一般'
    return '补遗'


def glosses(word: dict[str, object]) -> list[str]:
    texts: list[str] = []
    seen: set[str] = set()
    for sense in word.get('sense') or []:
        for gloss in sense.get('gloss') or []:
            text = str(gloss.get('text') or '').strip()
            if text and text not in seen:
                seen.add(text)
                texts.append(text)
        if len(texts) >= 4:
            break
    return texts[:6]


def build_extra(
    existing_ids: set[str],
    wadoku: dict[tuple[str, str], list[tuple[int, str]]],
    kanjium: dict[tuple[str, str], list[tuple[int, str]]],
) -> dict[str, list[OrderedDict[str, object]]]:
    download(JMDICT_COMMON_URL, CACHE / 'jmdict-eng-common.json.zip')
    download(JMDICT_XML_URL, CACHE / 'JMdict_e.gz')
    priority = load_priority(CACHE / 'JMdict_e.gz')
    grouped: dict[str, list[OrderedDict[str, object]]] = defaultdict(list)
    for word in load_common_jmdict(CACHE / 'jmdict-eng-common.json.zip'):
        seq = str(word.get('id') or '')
        entry_id = f'jmdict-{seq}'
        if not seq or seq in existing_ids or entry_id in existing_ids:
            continue
        writing, reading = pick_headword(word)
        meanings = glosses(word)
        pitches = to_pitches(reading, lookup(writing, reading, wadoku, kanjium))
        level = lexicon_level(priority.get(seq, set()))
        grouped[level].append(order_entry({
            'id': entry_id,
            'level': level,
            'word': writing,
            'reading': reading,
            'meanings': meanings,
            'common': True,
        }, pitches))
    for level, entries in grouped.items():
        entries.sort(key=lambda item: (str(item['reading']), str(item['word']), str(item['id'])))
    return grouped


def order_entry(entry: dict[str, object], pitches: list[dict[str, object]]) -> OrderedDict[str, object]:
    ordered: OrderedDict[str, object] = OrderedDict()
    ordered['id'] = entry['id']
    ordered['level'] = entry['level']
    ordered['word'] = entry['word']
    ordered['reading'] = entry['reading']
    ordered['meanings'] = entry['meanings']
    ordered['common'] = entry['common']
    ordered['pitches'] = pitches
    if 'example' in entry:
        ordered['example'] = entry['example']
    return ordered


def main() -> None:
    download(WADOKU_URL, CACHE / 'WaDokuDa.tab')
    download(KANJIUM_URL, CACHE / 'kanjium-accents.txt')
    wadoku = load_wadoku(CACHE / 'WaDokuDa.tab')
    kanjium = load_kanjium(CACHE / 'kanjium-accents.txt')

    totals: dict[str, int] = {}
    covered = 0
    total = 0
    sources = {'wadoku': 0, 'kanjium': 0}
    existing_ids: set[str] = set()

    for level in LEVELS:
        path = VOCAB_DIR / f'{level}.json'
        entries = json.loads(path.read_text(encoding='utf-8'))
        rebuilt: list[OrderedDict[str, object]] = []
        for entry in entries:
            existing_ids.add(str(entry['id']))
            existing_ids.add(str(entry['id']).removeprefix('jmdict-'))
            hits = lookup(entry['word'], entry['reading'], wadoku, kanjium)
            pitches = to_pitches(entry['reading'], hits)
            if pitches:
                covered += 1
                sources[str(pitches[0]['source'])] += 1
            rebuilt.append(order_entry(entry, pitches))
            total += 1
        path.write_text(
            json.dumps(rebuilt, ensure_ascii=False, separators=(',', ':')),
            encoding='utf-8',
        )
        totals[level.upper()] = len(rebuilt)

    extras = build_extra(existing_ids, wadoku, kanjium)
    extra_total = 0
    extra_covered = 0
    extra_sources = {'wadoku': 0, 'kanjium': 0}
    for level, filename in LEXICON_FILES.items():
        entries = extras.get(level, [])
        extra_total += len(entries)
        totals[level] = len(entries)
        for entry in entries:
            pitches = list(entry['pitches'])
            if pitches:
                extra_covered += 1
                extra_sources[str(pitches[0]['source'])] += 1
        (VOCAB_DIR / f'{filename}.json').write_text(
            json.dumps(entries, ensure_ascii=False, separators=(',', ':')),
            encoding='utf-8',
        )

    manifest_path = CONTENT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest['vocabulary'] = {
        'total': total,
        'extraTotal': extra_total,
        'lexiconTotal': total + extra_total,
        'levels': totals,
        'pitchCoverage': covered,
        'extraPitchCoverage': extra_covered,
        'pitchSources': sources,
        'extraPitchSources': extra_sources,
        'sourceVersion': 'JMdict common + Waller JLPT + Wadoku/Kanjium pitch 2026-09-02',
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8',
    )
    print(
        f'Exam pitches: {covered}/{total} '
        f'(wadoku {sources["wadoku"]}, kanjium {sources["kanjium"]})'
    )
    print(
        'Lexicon extras: '
        + ', '.join(f'{level} {totals.get(level, 0)}' for level in LEXICON_FILES)
        + f' ({extra_covered}/{extra_total} with pitch)'
    )


if __name__ == '__main__':
    main()
