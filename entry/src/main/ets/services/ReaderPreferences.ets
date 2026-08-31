import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'kotoba_reader';
const KEY_FONT_SIZE: string = 'style.font_size';
const KEY_LINE_HEIGHT: string = 'style.line_height';
const KEY_FLIP_MODE: string = 'style.flip_mode';
const KEY_THEME_INDEX: string = 'style.theme_index';

export interface ReaderStyleSnapshot {
  fontSize: number;
  lineHeight: number;
  flipMode: number;
  themeIndex: number;
}

export interface ReaderProgressSnapshot {
  resourceIndex: number;
  domPos: string;
  pageOffset: number;
}

export class ReaderPreferences {
  private static store(context: common.Context): preferences.Preferences {
    try {
      return preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (error) {
      throw new Error('Unable to open reader preferences');
    }
  }

  private static safeId(readingId: string): string {
    return readingId.replace(/[^A-Za-z0-9_-]/g, '_');
  }

  private static progressKey(readingId: string, field: string): string {
    return `progress.${ReaderPreferences.safeId(readingId)}.${field}`;
  }

  static hasStyle(context: common.Context): boolean {
    try {
      return ReaderPreferences.store(context).hasSync(KEY_FONT_SIZE);
    } catch (error) {
      return false;
    }
  }

  static style(context: common.Context): ReaderStyleSnapshot {
    try {
      const store: preferences.Preferences = ReaderPreferences.store(context);
      return {
        fontSize: store.getSync(KEY_FONT_SIZE, 22) as number,
        lineHeight: store.getSync(KEY_LINE_HEIGHT, 1.9) as number,
        flipMode: store.getSync(KEY_FLIP_MODE, 0) as number,
        themeIndex: store.getSync(KEY_THEME_INDEX, 0) as number
      };
    } catch (error) {
      return { fontSize: 22, lineHeight: 1.9, flipMode: 0, themeIndex: 0 };
    }
  }

  static saveStyle(context: common.Context, style: ReaderStyleSnapshot): void {
    try {
      const store: preferences.Preferences = ReaderPreferences.store(context);
      store.putSync(KEY_FONT_SIZE, style.fontSize);
      store.putSync(KEY_LINE_HEIGHT, style.lineHeight);
      store.putSync(KEY_FLIP_MODE, style.flipMode);
      store.putSync(KEY_THEME_INDEX, style.themeIndex);
      store.flush();
    } catch (error) {
      return;
    }
  }

  static progress(context: common.Context, readingId: string): ReaderProgressSnapshot {
    try {
      const store: preferences.Preferences = ReaderPreferences.store(context);
      return {
        resourceIndex: store.getSync(
          ReaderPreferences.progressKey(readingId, 'resource_index'), 0) as number,
        domPos: store.getSync(ReaderPreferences.progressKey(readingId, 'dom_pos'), '') as string,
        pageOffset: store.getSync(ReaderPreferences.progressKey(readingId, 'page_offset'), 0) as number
      };
    } catch (error) {
      return { resourceIndex: 0, domPos: '', pageOffset: 0 };
    }
  }

  static saveProgress(context: common.Context, readingId: string,
    progress: ReaderProgressSnapshot): void {
    try {
      const store: preferences.Preferences = ReaderPreferences.store(context);
      store.putSync(ReaderPreferences.progressKey(readingId, 'resource_index'), progress.resourceIndex);
      store.putSync(ReaderPreferences.progressKey(readingId, 'dom_pos'), progress.domPos);
      store.putSync(ReaderPreferences.progressKey(readingId, 'page_offset'), progress.pageOffset);
      store.flush();
    } catch (error) {
      return;
    }
  }
}
