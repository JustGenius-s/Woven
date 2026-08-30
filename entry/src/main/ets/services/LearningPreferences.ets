import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'kotoba_settings';
const KEY_DEEPSEEK_API_KEY: string = 'deepseek_api_key';
const KEY_GRAMMAR_INDEX: string = 'grammar_index';
const KEY_SECTION: string = 'section';
const KEY_JOURNEY_ID: string = 'journey_id';
const KEY_JOURNEY_STAGE: string = 'journey_stage';
const KEY_JOURNEY_COMPLETED_MASK: string = 'journey_completed_mask';
const KEY_HOME_GUIDE_SEEN: string = 'home_guide_seen';

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

  static grammarIndex(context: common.Context): number {
    return LearningPreferences.readNumber(context, KEY_GRAMMAR_INDEX, 0);
  }

  static deepSeekApiKey(context: common.Context): string {
    return LearningPreferences.readString(context, KEY_DEEPSEEK_API_KEY, '');
  }

  static section(context: common.Context): number {
    return LearningPreferences.readNumber(context, KEY_SECTION, 0);
  }

  static journeyId(context: common.Context): string {
    return LearningPreferences.readString(context, KEY_JOURNEY_ID, 'first-meeting');
  }

  static journeyStage(context: common.Context): number {
    return LearningPreferences.readNumber(context, KEY_JOURNEY_STAGE, 0);
  }

  static journeyCompletedMask(context: common.Context): number {
    return LearningPreferences.readNumber(context, KEY_JOURNEY_COMPLETED_MASK, 0);
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
        if (store.hasSync(historyKeys[index])) {
          return false;
        }
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  static saveGrammarIndex(context: common.Context, index: number): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_GRAMMAR_INDEX, index);
      store.flush();
    } catch (error) {
      return;
    }
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

  static saveSection(context: common.Context, section: number): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_SECTION, section);
      store.flush();
    } catch (error) {
      return;
    }
  }

  static saveJourneyProgress(context: common.Context, journeyId: string, stage: number,
    completedMask: number): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_JOURNEY_ID, journeyId);
      store.putSync(KEY_JOURNEY_STAGE, stage);
      store.putSync(KEY_JOURNEY_COMPLETED_MASK, completedMask);
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

}
