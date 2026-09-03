/**
 * Minimal Markdown model for AI answers.
 *
 * The renderer covers only what the DeepSeek prompts are told to emit:
 * headings, paragraphs, bullet/ordered lists, block quotes, fenced code,
 * tables, rules, and inline bold / italic / inline-code / links.
 * Anything else degrades to plain text instead of showing raw syntax.
 */

export const MD_HEADING: string = 'heading';
export const MD_PARAGRAPH: string = 'paragraph';
export const MD_LIST: string = 'list';
export const MD_QUOTE: string = 'quote';
export const MD_CODE: string = 'code';
export const MD_TABLE: string = 'table';
export const MD_RULE: string = 'rule';

export const MD_TEXT: string = 'text';
export const MD_BOLD: string = 'bold';
export const MD_ITALIC: string = 'italic';
export const MD_BOLD_ITALIC: string = 'bold_italic';
export const MD_INLINE_CODE: string = 'code';
export const MD_LINK: string = 'link';

/**
 * A parsed inline run. `text` is always the visible text: link syntax is
 * reduced to its label, emphasis markers are stripped, and `code` carries the
 * literal body so the renderer can give it a monospaced chip.
 */
export interface MarkdownSpan {
  kind: string;
  text: string;
  href: string;
}

export interface MarkdownListItem {
  text: string;
  depth: number;
}

export interface MarkdownBlock {
  kind: string;
  /** Heading level 1..6 for `heading`, otherwise 0. */
  level: number;
  /** Paragraph / quote text, or the body of a fenced code block. */
  text: string;
  spans: MarkdownSpan[];
  items: MarkdownListItem[];
  /** True when a list block is ordered rather than bulleted. */
  ordered: boolean;
  /** Optional language hint from a fenced code block's info string. */
  language: string;
  /** Row-major table cells; the first row is the header. */
  cells: string[][];
}

export interface MarkdownDocument {
  blocks: MarkdownBlock[];
}

export function emptyMarkdownBlock(): MarkdownBlock {
  return {
    kind: MD_PARAGRAPH,
    level: 0,
    text: '',
    spans: [],
    items: [],
    ordered: false,
    language: '',
    cells: []
  };
}

export function plainMarkdownSpan(text: string): MarkdownSpan {
  return { kind: MD_TEXT, text: text, href: '' };
}
