import {
  GrammarBlock,
  GrammarDocument,
  GrammarVocabularyEntry,
  InlineSegment
} from '../model/ContentModels';

const BLOCK_HEADING: string = 'heading';
const BLOCK_SUBHEADING: string = 'subheading';
const BLOCK_PARAGRAPH: string = 'paragraph';
const BLOCK_NOTE: string = 'note';
const BLOCK_LIST: string = 'list';
const BLOCK_TABLE: string = 'table';

export class GrammarParser {
  static parse(source: string): GrammarDocument {
    const normalized: string = source.replace(/\r\n?/g, '\n');
    const lines: string[] = normalized.split('\n');
    const vocabulary: GrammarVocabularyEntry[] = GrammarParser.readVocabulary(lines);
    const contentStart: number = GrammarParser.contentStart(lines, vocabulary.length > 0);
    const blocks: GrammarBlock[] = [];
    let cursor: number = contentStart;

    while (cursor < lines.length) {
      const line: string = lines[cursor].trim();
      if (line.length === 0 || /^---+$/.test(line)) {
        cursor += 1;
        continue;
      }
      if (/^#{3,6}\s+/.test(line)) {
        blocks.push(GrammarParser.block(BLOCK_SUBHEADING,
          GrammarParser.cleanInline(line.replace(/^#{3,6}\s+/, ''))));
        cursor += 1;
        continue;
      }
      if (line.startsWith('## ')) {
        blocks.push(GrammarParser.block(BLOCK_HEADING, GrammarParser.cleanInline(line.slice(3))));
        cursor += 1;
        continue;
      }
      if (line.startsWith('>')) {
        const noteLines: string[] = [];
        while (cursor < lines.length && lines[cursor].trim().startsWith('>')) {
          noteLines.push(GrammarParser.cleanInline(lines[cursor].trim().replace(/^>\s?/, '')));
          cursor += 1;
        }
        blocks.push(GrammarParser.block(BLOCK_NOTE, noteLines.join('\n')));
        continue;
      }
      if (GrammarParser.isTableLine(line) && cursor + 1 < lines.length &&
        GrammarParser.isTableDivider(lines[cursor + 1].trim())) {
        const rows: string[][] = [];
        rows.push(GrammarParser.splitTable(line));
        cursor += 2;
        while (cursor < lines.length && GrammarParser.isTableLine(lines[cursor].trim())) {
          rows.push(GrammarParser.splitTable(lines[cursor].trim()));
          cursor += 1;
        }
        blocks.push({ kind: BLOCK_TABLE, text: '', cells: rows });
        continue;
      }
      if (GrammarParser.isListLine(line)) {
        const items: string[] = [];
        const ordered: boolean = /^\d+[.)]\s+/.test(line);
        while (cursor < lines.length && GrammarParser.isListLine(lines[cursor].trim())) {
          items.push(GrammarParser.cleanInline(lines[cursor].trim().replace(/^[-*]\s+/, '')
            .replace(/^\d+[.)]\s+/, '')
            .replace(/^\[[ xX]\]\s*/, '')));
          cursor += 1;
        }
        blocks.push({ kind: BLOCK_LIST, text: items.join('\n'), cells: [], ordered: ordered });
        continue;
      }

      const paragraph: string[] = [];
      while (cursor < lines.length) {
        const current: string = lines[cursor].trim();
        if (current.length === 0 || current.startsWith('##') || current.startsWith('>') ||
          GrammarParser.isListLine(current) || GrammarParser.isTableLine(current) || /^---+$/.test(current)) {
          break;
        }
        paragraph.push(GrammarParser.cleanInline(current));
        cursor += 1;
      }
      if (paragraph.length > 0) {
        blocks.push(GrammarParser.block(BLOCK_PARAGRAPH, paragraph.join(' ')));
      } else {
        cursor += 1;
      }
    }

    return { blocks: blocks, vocabulary: vocabulary };
  }

  static annotate(text: string, vocabulary: GrammarVocabularyEntry[]): InlineSegment[] {
    if (text.length === 0 || vocabulary.length === 0) {
      return [GrammarParser.segment(text)];
    }
    const ordered: GrammarVocabularyEntry[] = vocabulary.slice().sort((left: GrammarVocabularyEntry,
      right: GrammarVocabularyEntry) => right.word.length - left.word.length);
    const result: InlineSegment[] = [];
    let cursor: number = 0;
    while (cursor < text.length) {
      let match: GrammarVocabularyEntry | undefined = undefined;
      for (let index: number = 0; index < ordered.length; index++) {
        const candidate: GrammarVocabularyEntry = ordered[index];
        if (candidate.word.length > 0 && text.startsWith(candidate.word, cursor)) {
          match = candidate;
          break;
        }
      }
      if (match !== undefined) {
        result.push({
          text: match.word,
          word: match.word,
          reading: match.reading,
          meaning: match.meaning,
          annotated: true
        });
        cursor += match.word.length;
      } else {
        const plainStart: number = cursor;
        cursor += 1;
        while (cursor < text.length) {
          let found: boolean = false;
          for (let index: number = 0; index < ordered.length; index++) {
            if (ordered[index].word.length > 0 && text.startsWith(ordered[index].word, cursor)) {
              found = true;
              break;
            }
          }
          if (found) {
            break;
          }
          cursor += 1;
        }
        result.push(GrammarParser.segment(text.slice(plainStart, cursor)));
      }
    }
    return result;
  }

  private static readVocabulary(lines: string[]): GrammarVocabularyEntry[] {
    let heading: number = -1;
    for (let index: number = 0; index < lines.length; index++) {
      if (/^##\s+本课(?:单词|词汇)表\s*$/.test(lines[index].trim())) {
        heading = index;
        break;
      }
    }
    if (heading < 0) {
      return [];
    }
    let cursor: number = heading + 1;
    while (cursor < lines.length && lines[cursor].trim().length === 0) {
      cursor += 1;
    }
    if (cursor + 1 >= lines.length || !GrammarParser.isTableLine(lines[cursor].trim()) ||
      !GrammarParser.isTableDivider(lines[cursor + 1].trim())) {
      return [];
    }
    cursor += 2;
    const entries: GrammarVocabularyEntry[] = [];
    while (cursor < lines.length && GrammarParser.isTableLine(lines[cursor].trim())) {
      const cells: string[] = GrammarParser.splitTable(lines[cursor].trim());
      if (cells.length >= 3 && cells[0].length > 0) {
        entries.push({ word: cells[0], reading: cells[1], meaning: cells.slice(2).join(' ') });
      }
      cursor += 1;
    }
    return entries;
  }

  private static contentStart(lines: string[], hasVocabulary: boolean): number {
    if (!hasVocabulary) {
      return 0;
    }
    let cursor: number = 0;
    while (cursor < lines.length && !/^##\s+本课(?:单词|词汇)表\s*$/.test(lines[cursor].trim())) {
      cursor += 1;
    }
    while (cursor < lines.length && !/^---+$/.test(lines[cursor].trim())) {
      cursor += 1;
    }
    return cursor < lines.length ? cursor + 1 : 0;
  }

  private static block(kind: string, text: string): GrammarBlock {
    return { kind: kind, text: text, cells: [] };
  }

  private static segment(text: string): InlineSegment {
    return { text: text, word: '', reading: '', meaning: '', annotated: false };
  }

  private static isListLine(line: string): boolean {
    return /^[-*]\s+/.test(line) || /^\d+[.)]\s+/.test(line);
  }

  private static isTableLine(line: string): boolean {
    return line.startsWith('|') && line.endsWith('|');
  }

  private static isTableDivider(line: string): boolean {
    return /^\|(?:\s*:?-{3,}:?\s*\|)+$/.test(line);
  }

  private static splitTable(line: string): string[] {
    const raw: string = line.slice(1, line.length - 1);
    const cells: string[] = raw.split('|');
    const result: string[] = [];
    for (let index: number = 0; index < cells.length; index++) {
      result.push(GrammarParser.cleanInline(cells[index].trim()));
    }
    return result;
  }

  private static cleanInline(value: string): string {
    return value.replace(/\*\*|__|`/g, '')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/：：/g, '。')
      .trim();
  }
}
