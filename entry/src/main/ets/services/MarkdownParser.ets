import {
  MarkdownBlock,
  MarkdownDocument,
  MarkdownListItem,
  MarkdownSpan,
  MD_BOLD,
  MD_BOLD_ITALIC,
  MD_CODE,
  MD_HEADING,
  MD_INLINE_CODE,
  MD_ITALIC,
  MD_LINK,
  MD_LIST,
  MD_PARAGRAPH,
  MD_QUOTE,
  MD_RULE,
  MD_TABLE,
  MD_TEXT,
  plainMarkdownSpan
} from '../model/MarkdownModels';

const LIST_INDENT: number = 2;
const MAX_LIST_DEPTH: number = 2;

/**
 * Block-level Markdown parser for AI answers.
 *
 * Deliberately small: it understands the subset the DeepSeek prompts ask the
 * model to produce (headings, paragraphs, lists, quotes, fenced code, tables
 * and rules) and renders everything else as plain text. Unclosed emphasis or
 * an unterminated code fence degrade to literal text rather than throwing, so
 * a half-streamed answer never leaves the bubble empty.
 */
export class MarkdownParser {
  static parse(source: string): MarkdownDocument {
    const lines: string[] = source.replace(/\r\n?/g, '\n').split('\n');
    const blocks: MarkdownBlock[] = [];
    let cursor: number = 0;

    while (cursor < lines.length) {
      const trimmed: string = lines[cursor].trim();
      if (trimmed.length === 0) {
        cursor += 1;
        continue;
      }
      if (MarkdownParser.isFence(trimmed)) {
        const language: string = MarkdownParser.fenceLanguage(trimmed);
        cursor += 1;
        const body: string[] = [];
        while (cursor < lines.length && !MarkdownParser.isFence(lines[cursor].trim())) {
          body.push(lines[cursor]);
          cursor += 1;
        }
        if (cursor < lines.length) {
          cursor += 1;
        }
        blocks.push(MarkdownParser.codeBlock(body.join('\n'), language));
        continue;
      }
      if (trimmed.startsWith('>')) {
        const quote: string[] = [];
        while (cursor < lines.length && lines[cursor].trim().startsWith('>')) {
          quote.push(MarkdownParser.trimQuote(lines[cursor].trim()));
          cursor += 1;
        }
        blocks.push(MarkdownParser.textBlock(MD_QUOTE, quote.join('\n')));
        continue;
      }
      const level: number = MarkdownParser.headingLevel(trimmed);
      if (level > 0) {
        blocks.push(MarkdownParser.headingBlock(level, trimmed.slice(level).trim()));
        cursor += 1;
        continue;
      }
      if (MarkdownParser.isRule(trimmed)) {
        blocks.push(MarkdownParser.simpleBlock(MD_RULE));
        cursor += 1;
        continue;
      }
      if (MarkdownParser.isTableLine(trimmed) && cursor + 1 < lines.length &&
        MarkdownParser.isTableDivider(lines[cursor + 1].trim())) {
        const cells: string[][] = [];
        cells.push(MarkdownParser.splitRow(trimmed));
        cursor += 2;
        while (cursor < lines.length && MarkdownParser.isTableLine(lines[cursor].trim())) {
          cells.push(MarkdownParser.splitRow(lines[cursor].trim()));
          cursor += 1;
        }
        blocks.push(MarkdownParser.tableBlock(cells));
        continue;
      }
      if (MarkdownParser.listIndent(lines[cursor]) >= 0) {
        const ordered: boolean = MarkdownParser.isOrderedItem(lines[cursor].trim());
        const items: MarkdownListItem[] = [];
        while (cursor < lines.length) {
          const current: string = lines[cursor];
          const indent: number = MarkdownParser.listIndent(current);
          if (indent < 0) {
            if (items.length === 0 || current.trim().length === 0) {
              break;
            }
            // Lazy continuation: an unindented line keeps the current item.
            items[items.length - 1].text = `${items[items.length - 1].text}\n${current.trim()}`;
            cursor += 1;
            continue;
          }
          items.push({
            text: MarkdownParser.itemText(current.trim()),
            depth: MarkdownParser.itemDepth(indent)
          });
          cursor += 1;
        }
        blocks.push(MarkdownParser.listBlock(items, ordered));
        continue;
      }

      const paragraph: string[] = [];
      while (cursor < lines.length) {
        const current: string = lines[cursor];
        const currentTrimmed: string = current.trim();
        if (currentTrimmed.length === 0 || MarkdownParser.isFence(currentTrimmed) ||
          MarkdownParser.headingLevel(currentTrimmed) > 0 || MarkdownParser.isRule(currentTrimmed) ||
          MarkdownParser.listIndent(current) >= 0 || currentTrimmed.startsWith('>') ||
          MarkdownParser.isTableLine(currentTrimmed)) {
          break;
        }
        paragraph.push(currentTrimmed);
        cursor += 1;
      }
      if (paragraph.length > 0) {
        // Kept as separate lines: the role-play prompt asks the model to put its
        // Chinese hint "on the next line", so a soft break has to survive.
        blocks.push(MarkdownParser.textBlock(MD_PARAGRAPH, paragraph.join('\n')));
      } else {
        cursor += 1;
      }
    }

    return { blocks: blocks };
  }

  /**
   * Splits a run of text into styled spans. Markers are consumed; the returned
   * `text` values are always what the reader should see.
   */
  static parseInline(source: string): MarkdownSpan[] {
    const spans: MarkdownSpan[] = [];
    if (source.length === 0) {
      return spans;
    }
    let plain: string = '';
    let cursor: number = 0;
    while (cursor < source.length) {
      const marker: string = MarkdownParser.markerAt(source, cursor);
      if (marker.length === 0) {
        plain += source.charAt(cursor);
        cursor += 1;
        continue;
      }
      const match: MarkdownSpan | undefined = MarkdownParser.matchSpan(source, cursor, marker);
      if (match === undefined) {
        plain += source.charAt(cursor);
        cursor += 1;
        continue;
      }
      MarkdownParser.pushPlain(spans, plain);
      plain = '';
      // Nested emphasis inside a bold run was already flattened by `matchSpan`'s
      // own `stripInline` call; re-parsing it here would double-strip markers.
      spans.push(match);
      cursor = MarkdownParser.markerEnd(source, cursor, marker);
    }
    MarkdownParser.pushPlain(spans, plain);
    return spans;
  }

  /** Visible text with every inline marker removed, for plain-text contexts. */
  static stripInline(source: string): string {
    const spans: MarkdownSpan[] = MarkdownParser.parseInline(source);
    let text: string = '';
    for (let index: number = 0; index < spans.length; index++) {
      text += spans[index].text;
    }
    return text;
  }

  private static markerAt(source: string, cursor: number): string {
    if (source.startsWith('***', cursor)) {
      return '***';
    }
    if (source.startsWith('**', cursor) || source.startsWith('__', cursor)) {
      return source.slice(cursor, cursor + 2);
    }
    if (source.startsWith('`', cursor)) {
      return '`';
    }
    if (source.startsWith('[', cursor)) {
      return '[';
    }
    if (source.startsWith('*', cursor)) {
      return '*';
    }
    if (source.startsWith('_', cursor)) {
      return '_';
    }
    return '';
  }

  private static markerEnd(source: string, cursor: number, marker: string): number {
    if (marker === '[') {
      const close: number = source.indexOf(')', cursor);
      return close < 0 ? cursor + 1 : close + 1;
    }
    return cursor + MarkdownParser.closingLength(source, cursor, marker) + 2 * marker.length;
  }

  private static closingLength(source: string, cursor: number, marker: string): number {
    if (marker === '`') {
      const end: number = source.indexOf('`', cursor + 1);
      return end < 0 ? -1 : end - cursor - 1;
    }
    if (marker === '***') {
      const end: number = source.indexOf('***', cursor + 3);
      return end < 0 ? -1 : end - cursor - 3;
    }
    if (marker === '**' || marker === '__') {
      const end: number = source.indexOf(marker, cursor + 2);
      if (end < 0 || end <= cursor + 2) {
        return -1;
      }
      return end - cursor - 2;
    }
    if (marker === '*') {
      const end: number = source.indexOf('*', cursor + 1);
      if (end <= cursor + 1) {
        return -1;
      }
      return end - cursor - 1;
    }
    const end: number = source.indexOf('_', cursor + 1);
    if (end <= cursor + 1) {
      return -1;
    }
    return end - cursor - 1;
  }

  private static matchSpan(source: string, cursor: number, marker: string): MarkdownSpan | undefined {
    // Links are matched before the generic marker logic: `[label](url)` has no
    // symmetric closing marker, so the span length has to come from the URL.
    if (marker === '[') {
      return MarkdownParser.linkSpan(source, cursor);
    }
    const length: number = MarkdownParser.closingLength(source, cursor, marker);
    if (length < 0) {
      return undefined;
    }
    const shift: number = marker === '***' ? 3 : marker.length;
    const inner: string = source.slice(cursor + shift, cursor + shift + length);
    if (inner.trim().length === 0) {
      return undefined;
    }
    if (marker === '`') {
      return { kind: MD_INLINE_CODE, text: inner, href: '' };
    }
    if (marker === '***') {
      return { kind: MD_BOLD_ITALIC, text: MarkdownParser.stripInline(inner), href: '' };
    }
    if (marker === '**' || marker === '__') {
      return { kind: MD_BOLD, text: MarkdownParser.stripInline(inner), href: '' };
    }
    if (marker === '*') {
      return { kind: MD_ITALIC, text: MarkdownParser.stripInline(inner), href: '' };
    }
    // `_` only emphasises at word boundaries, so snake_case stays readable.
    if (cursor > 0 && MarkdownParser.isWordChar(source.charAt(cursor - 1))) {
      return undefined;
    }
    const after: number = cursor + 1 + length;
    if (after < source.length && MarkdownParser.isWordChar(source.charAt(after))) {
      return undefined;
    }
    return { kind: MD_ITALIC, text: MarkdownParser.stripInline(inner), href: '' };
  }

  private static linkSpan(source: string, cursor: number): MarkdownSpan | undefined {
    const labelEnd: number = source.indexOf(']', cursor);
    if (labelEnd < cursor + 2 || labelEnd + 1 >= source.length || source.charAt(labelEnd + 1) !== '(') {
      return undefined;
    }
    const urlEnd: number = source.indexOf(')', labelEnd + 2);
    if (urlEnd < 0) {
      return undefined;
    }
    const label: string = source.slice(cursor + 1, labelEnd);
    const href: string = source.slice(labelEnd + 2, urlEnd).trim();
    if (label.length === 0 || href.length === 0) {
      return undefined;
    }
    return { kind: MD_LINK, text: label, href: href };
  }

  private static pushPlain(spans: MarkdownSpan[], text: string): void {
    if (text.length > 0) {
      spans.push(plainMarkdownSpan(text));
    }
  }

  private static isWordChar(value: string): boolean {
    return /[A-Za-z0-9_]/.test(value);
  }

  private static isFence(line: string): boolean {
    return line.startsWith('```') || line.startsWith('~~~');
  }

  private static fenceLanguage(line: string): string {
    let cursor: number = 0;
    while (cursor < line.length && (line.charAt(cursor) === '`' || line.charAt(cursor) === '~')) {
      cursor += 1;
    }
    return line.slice(cursor).trim();
  }

  private static trimQuote(line: string): string {
    return line.replace(/^>\s?/, '');
  }

  private static headingLevel(line: string): number {
    let level: number = 0;
    while (level < line.length && level < 6 && line.charAt(level) === '#') {
      level += 1;
    }
    if (level === 0 || level >= line.length || line.charAt(level) !== ' ') {
      return 0;
    }
    return level;
  }

  private static isRule(line: string): boolean {
    return /^-{3,}$/.test(line) || /^\*{3,}$/.test(line) || /^_{3,}$/.test(line);
  }

  private static listIndent(line: string): number {
    if (line.trim().length === 0) {
      return -1;
    }
    let indent: number = 0;
    while (indent < line.length && (line.charAt(indent) === ' ' || line.charAt(indent) === '\t')) {
      indent += 1;
    }
    const trimmed: string = line.trim();
    if (/^[-*+]\s+/.test(trimmed) || /^\d{1,3}[.)]\s+/.test(trimmed)) {
      return indent;
    }
    return -1;
  }

  private static isOrderedItem(trimmed: string): boolean {
    return /^\d{1,3}[.)]\s+/.test(trimmed);
  }

  /**
   * Indentation is floored to whole indent steps so a 3-space indent — which
   * models emit as often as 2 or 4 — cannot produce a fractional depth and
   * leave the renderer indexing past the end of its bullet list.
   */
  private static itemDepth(indent: number): number {
    if (indent < LIST_INDENT) {
      return 0;
    }
    if (indent < LIST_INDENT * 2) {
      return 1;
    }
    return MAX_LIST_DEPTH;
  }

  private static itemText(trimmed: string): string {
    return trimmed.replace(/^[-*+]\s+/, '').replace(/^\d{1,3}[.)]\s+/, '')
      .replace(/^\[[ xX]\]\s*/, '').trim();
  }

  private static isTableLine(line: string): boolean {
    return line.startsWith('|') && line.endsWith('|') && line.length > 1;
  }

  private static isTableDivider(line: string): boolean {
    return /^\|(?:\s*:?-{3,}:?\s*\|)+$/.test(line);
  }

  private static splitRow(line: string): string[] {
    const cells: string[] = line.slice(1, line.length - 1).split('|');
    const result: string[] = [];
    for (let index: number = 0; index < cells.length; index++) {
      result.push(MarkdownParser.stripInline(cells[index].trim()));
    }
    return result;
  }

  private static simpleBlock(kind: string): MarkdownBlock {
    return {
      kind: kind,
      level: 0,
      text: '',
      spans: [],
      items: [],
      ordered: false,
      language: '',
      cells: []
    };
  }

  private static textBlock(kind: string, text: string): MarkdownBlock {
    return {
      kind: kind,
      level: 0,
      text: text,
      spans: MarkdownParser.parseInline(text),
      items: [],
      ordered: false,
      language: '',
      cells: []
    };
  }

  private static headingBlock(level: number, text: string): MarkdownBlock {
    return {
      kind: MD_HEADING,
      level: level,
      text: text,
      spans: MarkdownParser.parseInline(text),
      items: [],
      ordered: false,
      language: '',
      cells: []
    };
  }

  private static codeBlock(text: string, language: string): MarkdownBlock {
    return {
      kind: MD_CODE,
      level: 0,
      text: text,
      spans: [],
      items: [],
      ordered: false,
      language: language,
      cells: []
    };
  }

  private static listBlock(items: MarkdownListItem[], ordered: boolean): MarkdownBlock {
    return {
      kind: MD_LIST,
      level: 0,
      text: '',
      spans: [],
      items: items,
      ordered: ordered,
      language: '',
      cells: []
    };
  }

  private static tableBlock(cells: string[][]): MarkdownBlock {
    return {
      kind: MD_TABLE,
      level: 0,
      text: '',
      spans: [],
      items: [],
      ordered: false,
      language: '',
      cells: cells
    };
  }
}
