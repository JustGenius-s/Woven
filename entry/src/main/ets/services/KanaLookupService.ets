import { KanaCell, KanaGroups, KanaRow } from '../model/ContentModels';

type KanaQueryHandler = (query: string) => void;

/**
 * Carries a "look up in the kana chart" request from a selection menu to the
 * sheet that renders the chart.
 *
 * The selection menu is built by a plain function used at dozens of call sites,
 * so it cannot hold state or own a sheet. Routing the request through here lets
 * those call sites stay as they are; the sheet subscribes at the top level.
 */
export class KanaLookupService {
  private static handler: KanaQueryHandler | undefined = undefined;

  static subscribe(handler: KanaQueryHandler): void {
    KanaLookupService.handler = handler;
  }

  static unsubscribe(handler: KanaQueryHandler): void {
    if (KanaLookupService.handler === handler) {
      KanaLookupService.handler = undefined;
    }
  }

  static request(query: string): void {
    const text: string = query.trim();
    if (text.length === 0 || KanaLookupService.handler === undefined) {
      return;
    }
    KanaLookupService.handler(text);
  }
}

function collectCells(groups: KanaGroups): KanaCell[] {
  const cells: KanaCell[] = [];
  const sections: KanaRow[][] = [groups.basic, groups.voiced, groups.contracted];
  for (let sectionIndex: number = 0; sectionIndex < sections.length; sectionIndex++) {
    const rows: KanaRow[] = sections[sectionIndex];
    for (let rowIndex: number = 0; rowIndex < rows.length; rowIndex++) {
      const row: KanaRow = rows[rowIndex];
      for (let cellIndex: number = 0; cellIndex < row.cells.length; cellIndex++) {
        cells.push(row.cells[cellIndex]);
      }
    }
  }
  return cells;
}

/**
 * Keys of the kana that appear in `text`.
 *
 * Matches longest-first so a contracted kana such as きゃ is attributed to its
 * own cell rather than being counted as き plus a stray ゃ. Positions taken by a
 * longer match are consumed, so the shorter kana do not double up on them.
 */
export function matchKanaKeys(text: string, groups: KanaGroups): string[] {
  const cells: KanaCell[] = collectCells(groups);
  // Longest glyphs first.
  cells.sort((left: KanaCell, right: KanaCell) => right.hira.length - left.hira.length);

  const consumed: boolean[] = new Array<boolean>(text.length).fill(false);
  const matched: string[] = [];

  for (let cellIndex: number = 0; cellIndex < cells.length; cellIndex++) {
    const cell: KanaCell = cells[cellIndex];
    const glyphs: string[] = [cell.hira, cell.kata];
    for (let glyphIndex: number = 0; glyphIndex < glyphs.length; glyphIndex++) {
      const glyph: string = glyphs[glyphIndex];
      if (glyph.length === 0) {
        continue;
      }
      let from: number = 0;
      let found: boolean = false;
      while (from + glyph.length <= text.length) {
        const at: number = text.indexOf(glyph, from);
        if (at < 0) {
          break;
        }
        // Only a run of untouched positions counts as a match.
        let clear: boolean = true;
        for (let offset: number = 0; offset < glyph.length; offset++) {
          if (consumed[at + offset]) {
            clear = false;
            break;
          }
        }
        if (clear) {
          for (let offset: number = 0; offset < glyph.length; offset++) {
            consumed[at + offset] = true;
          }
          found = true;
          from = at + glyph.length;
        } else {
          from = at + 1;
        }
      }
      if (found && matched.indexOf(cell.key) < 0) {
        matched.push(cell.key);
      }
    }
  }
  return matched;
}

/**
 * True when any position in `text` was recognised as kana.
 */
export function hasKana(text: string, groups: KanaGroups): boolean {
  return matchKanaKeys(text, groups).length > 0;
}
