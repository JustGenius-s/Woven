import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DEFAULT_COURSE_ID } from '../model/SyncModels';

const STORE_NAME: string = 'kotoba_settings';
const KEY_DEEPSEEK_API_KEY: string = 'deepseek_api_key';
const KEY_MINIMAX_API_KEY: string = 'minimax_api_key';
const KEY_GRAMMAR_INDEX: string = 'grammar_index';
const KEY_SECTION: string = 'section';
const KEY_JOURNEY_ID: string = 'journey_id';
const KEY_JOURNEY_STAGE: string = 'journey_stage';
const KEY_JOURNEY_COMPLETED_MASK: string = 'journey_completed_mask';
const KEY_HOME_GUIDE_SEEN: string = 'home_guide_seen';
const KEY_KANA_KEY: string = 'kana_key';
const KEY_EXPLORE_TAB: string = 'explore_tab';
const KEY_MUSIC_INDEX: string = 'music_index';
const KEY_MUSIC_POSITION_PREFIX: string = 'music_position_';
const KEY_READING_INDEX: string = 'reading_index';
const KEY_SCENARIO_INDEX: string = 'scenario_index';

export class LearningPreferences {
  private static store(context: common.Context): preferences.Preferences {
    try {
      return preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (error) {
      throw new Error('Unable to open learning preferences');
    }
  }

  private static readString(context: common.Context, key: string, fallback: string): string {
    try {
      return LearningPreferences.store(context).getSync(key, fallback) as string;
    } catch (error) {
      return fallback;
    }
  }

  private static readNumber(context: common.Context, key: string, fallback: number): number {
    try {
      return LearningPreferences.store(context).getSync(key, fallback) as number;
    } catch (error) {
      return fallback;
    }
  }

  private static courseKey(key: string, courseId: string): string {
    return `course.${courseId.replace(/[^A-Za-z0-9_-]/g, '_')}.${key}`;
  }

  private static readCourseString(context: common.Context, key: string, fallback: string,
    courseId: string): string {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      const scopedKey: string = LearningPreferences.courseKey(key, courseId);
      if (store.hasSync(scopedKey)) {
        return store.getSync(scopedKey, fallback) as string;
      }
      return courseId === DEFAULT_COURSE_ID ? store.getSync(key, fallback) as string : fallback;
    } catch (error) {
      return fallback;
    }
  }

  private static readCourseNumber(context: common.Context, key: string, fallback: number,
    courseId: string): number {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      const scopedKey: string = LearningPreferences.courseKey(key, courseId);
      if (store.hasSync(scopedKey)) {
        return store.getSync(scopedKey, fallback) as number;
      }
      return courseId === DEFAULT_COURSE_ID ? store.getSync(key, fallback) as number : fallback;
    } catch (error) {
      return fallback;
    }
  }

  static grammarIndex(context: common.Context, courseId: string = DEFAULT_COURSE_ID): number {
    return LearningPreferences.readCourseNumber(context, KEY_GRAMMAR_INDEX, 0, courseId);
  }

  static deepSeekApiKey(context: common.Context): string {
    return LearningPreferences.readString(context, KEY_DEEPSEEK_API_KEY, '');
  }

  static minimaxApiKey(context: common.Context): string {
    return LearningPreferences.readString(context, KEY_MINIMAX_API_KEY, '');
  }

  static section(context: common.Context): number {
    return LearningPreferences.readNumber(context, KEY_SECTION, 0);
  }

  static journeyId(context: common.Context, courseId: string = DEFAULT_COURSE_ID): string {
    return LearningPreferences.readCourseString(context, KEY_JOURNEY_ID, 'first-meeting', courseId);
  }

  static journeyStage(context: common.Context, courseId: string = DEFAULT_COURSE_ID): number {
    return LearningPreferences.readCourseNumber(context, KEY_JOURNEY_STAGE, 0, courseId);
  }

  static journeyCompletedMask(context: common.Context, courseId: string = DEFAULT_COURSE_ID): number {
    return LearningPreferences.readCourseNumber(context, KEY_JOURNEY_COMPLETED_MASK, 0, courseId);
  }

  static kanaKey(context: common.Context, courseId: string = DEFAULT_COURSE_ID): string {
    return LearningPreferences.readCourseString(context, KEY_KANA_KEY, 'あ', courseId);
  }

  static exploreTab(context: common.Context, courseId: string = DEFAULT_COURSE_ID): number {
    return LearningPreferences.readCourseNumber(context, KEY_EXPLORE_TAB, 0, courseId);
  }

  static musicIndex(context: common.Context, courseId: string = DEFAULT_COURSE_ID): number {
    return LearningPreferences.readCourseNumber(context, KEY_MUSIC_INDEX, -1, courseId);
  }

  static musicPosition(context: common.Context, trackId: string,
    courseId: string = DEFAULT_COURSE_ID): number {
    return LearningPreferences.readCourseNumber(
      context, LearningPreferences.musicPositionKey(trackId), 0, courseId);
  }

  static readingIndex(context: common.Context, courseId: string = DEFAULT_COURSE_ID): number {
    return LearningPreferences.readCourseNumber(context, KEY_READING_INDEX, -1, courseId);
  }

  static scenarioIndex(context: common.Context, courseId: string = DEFAULT_COURSE_ID): number {
    return LearningPreferences.readCourseNumber(context, KEY_SCENARIO_INDEX, -1, courseId);
  }

  static shouldShowHomeGuide(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      if ((store.getSync(KEY_HOME_GUIDE_SEEN, 0) as number) === 1) {
        return false;
      }
      const historyKeys: string[] = [
        KEY_GRAMMAR_INDEX,
        KEY_SECTION,
        KEY_JOURNEY_ID,
        KEY_JOURNEY_STAGE,
        KEY_JOURNEY_COMPLETED_MASK
      ];
      for (let index: number = 0; index < historyKeys.length; index++) {
        if (store.hasSync(historyKeys[index]) ||
          store.hasSync(LearningPreferences.courseKey(historyKeys[index], DEFAULT_COURSE_ID))) {
          return false;
        }
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  static saveGrammarIndex(context: common.Context, index: number,
    courseId: string = DEFAULT_COURSE_ID): void {
    LearningPreferences.saveCourseNumber(context, KEY_GRAMMAR_INDEX, index, courseId);
  }

  static saveDeepSeekApiKey(context: common.Context, apiKey: string): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_DEEPSEEK_API_KEY, apiKey.trim());
      store.flush();
    } catch (error) {
      return;
    }
  }

  static saveMinimaxApiKey(context: common.Context, apiKey: string): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_MINIMAX_API_KEY, apiKey.trim());
      store.flush();
    } catch (error) {
      return;
    }
  }

  static saveSection(context: common.Context, section: number): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_SECTION, section);
      store.flush();
    } catch (error) {
      return;
    }
  }

  static saveKanaKey(context: common.Context, key: string, courseId: string = DEFAULT_COURSE_ID): void {
    LearningPreferences.saveCourseString(context, KEY_KANA_KEY, key, courseId);
  }

  static saveExploreTab(context: common.Context, index: number,
    courseId: string = DEFAULT_COURSE_ID): void {
    LearningPreferences.saveCourseNumber(context, KEY_EXPLORE_TAB, index, courseId);
  }

  static saveMusicIndex(context: common.Context, index: number,
    courseId: string = DEFAULT_COURSE_ID): void {
    LearningPreferences.saveCourseNumber(context, KEY_MUSIC_INDEX, index, courseId);
  }

  static saveMusicPosition(context: common.Context, trackId: string, positionMs: number,
    courseId: string = DEFAULT_COURSE_ID): void {
    LearningPreferences.saveCourseNumber(
      context,
      LearningPreferences.musicPositionKey(trackId),
      Math.max(0, Math.floor(positionMs)),
      courseId
    );
  }

  static saveReadingIndex(context: common.Context, index: number,
    courseId: string = DEFAULT_COURSE_ID): void {
    LearningPreferences.saveCourseNumber(context, KEY_READING_INDEX, index, courseId);
  }

  static saveScenarioIndex(context: common.Context, index: number,
    courseId: string = DEFAULT_COURSE_ID): void {
    LearningPreferences.saveCourseNumber(context, KEY_SCENARIO_INDEX, index, courseId);
  }

  static saveJourneyProgress(context: common.Context, journeyId: string, stage: number,
    completedMask: number, courseId: string = DEFAULT_COURSE_ID): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(LearningPreferences.courseKey(KEY_JOURNEY_ID, courseId), journeyId);
      store.putSync(LearningPreferences.courseKey(KEY_JOURNEY_STAGE, courseId), stage);
      store.putSync(LearningPreferences.courseKey(KEY_JOURNEY_COMPLETED_MASK, courseId), completedMask);
      store.flush();
    } catch (error) {
      return;
    }
  }

  static saveHomeGuideSeen(context: common.Context): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_HOME_GUIDE_SEEN, 1);
      store.flush();
    } catch (error) {
      return;
    }
  }

  private static saveString(context: common.Context, key: string, value: string): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(key, value);
      store.flush();
    } catch (error) {
      return;
    }
  }

  private static saveNumber(context: common.Context, key: string, value: number): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(key, value);
      store.flush();
    } catch (error) {
      return;
    }
  }

  private static saveCourseString(context: common.Context, key: string, value: string,
    courseId: string): void {
    LearningPreferences.saveString(context, LearningPreferences.courseKey(key, courseId), value);
  }

  private static saveCourseNumber(context: common.Context, key: string, value: number,
    courseId: string): void {
    LearningPreferences.saveNumber(context, LearningPreferences.courseKey(key, courseId), value);
  }

  private static musicPositionKey(trackId: string): string {
    return `${KEY_MUSIC_POSITION_PREFIX}${trackId.replace(/[^A-Za-z0-9_-]/g, '_')}`;
  }

}
