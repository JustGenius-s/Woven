import { KanaLookupService } from '../../services/KanaLookupService';

const ASK_AI_MENU_ID: TextMenuItemId = TextMenuItemId.of('kotoba.selection.ask_ai');
const KANA_MENU_ID: TextMenuItemId = TextMenuItemId.of('kotoba.selection.kana');

function selectedText(content: string, range: TextRange): string {
  const rawStart: number = range.start ?? 0;
  const rawEnd: number = range.end ?? content.length;
  const start: number = Math.max(0, Math.min(rawStart, content.length));
  const end: number = Math.max(start, Math.min(rawEnd, content.length));
  return content.slice(start, end).trim();
}

export function aiTextSelectionMenu(content: string, onAsk: (selected: string) => void): EditMenuOptions {
  return {
    onCreateMenu: (menuItems: TextMenuItem[]): TextMenuItem[] => {
      const next: TextMenuItem[] = [];
      for (let index: number = 0; index < menuItems.length; index++) {
        if (!menuItems[index].id.equals(ASK_AI_MENU_ID) &&
          !menuItems[index].id.equals(KANA_MENU_ID) &&
          !menuItems[index].id.equals(TextMenuItemId.askAI)) {
          next.push(menuItems[index]);
        }
      }
      next.push({
        content: '问 AI',
        id: ASK_AI_MENU_ID
      });
      next.push({
        content: '查五十音',
        id: KANA_MENU_ID
      });
      return next;
    },
    onMenuItemClick: (menuItem: TextMenuItem, range: TextRange): boolean => {
      const selection: string = selectedText(content, range);
      if (menuItem.id.equals(KANA_MENU_ID)) {
        // Routed through the service rather than a per-call-site callback: this
        // menu is built at dozens of call sites that all pass only onAsk.
        if (selection.length > 0) {
          KanaLookupService.request(selection);
        }
        return true;
      }
      if (!menuItem.id.equals(ASK_AI_MENU_ID)) {
        return false;
      }
      if (selection.length > 0) {
        onAsk(selection);
      }
      return true;
    }
  };
}
