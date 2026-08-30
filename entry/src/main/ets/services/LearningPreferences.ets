import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { VideoStudyItem } from '../model/ContentModels';

const STORE_NAME: string = 'kotoba_settings';
const KEY_GATEWAY_URL: string = 'gateway_url';
const KEY_APP_TOKEN: string = 'app_token';
const KEY_MODEL: string = 'model';
const KEY_GRAMMAR_INDEX: string = 'grammar_index';
const KEY_SECTION: string = 'section';
const KEY_VIDEOS: string = 'videos';
const KEY_JOURNEY_ID: string = 'journey_id';
const KEY_JOURNEY_STAGE: string = 'journey_stage';
const KEY_JOURNEY_COMPLETED_MASK: string = 'journey_completed_mask';

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

  static gatewayUrl(context: common.Context): string {
    return LearningPreferences.readString(context, KEY_GATEWAY_URL, 'http://127.0.0.1:8787');
  }

  static appToken(context: common.Context): string {
    return LearningPreferences.readString(context, KEY_APP_TOKEN, '');
  }

  static model(context: common.Context): string {
    return LearningPreferences.readString(context, KEY_MODEL, 'gpt-5.6-luna');
  }

  static grammarIndex(context: common.Context): number {
    return LearningPreferences.readNumber(context, KEY_GRAMMAR_INDEX, 0);
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

  static videos(context: common.Context): VideoStudyItem[] {
    const raw: string = LearningPreferences.readString(context, KEY_VIDEOS, '[]');
    try {
      return JSON.parse(raw) as VideoStudyItem[];
    } catch (error) {
      return [];
    }
  }

  static saveAiSettings(context: common.Context, gatewayUrl: string, appToken: string, model: string): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_GATEWAY_URL, gatewayUrl.trim().replace(/\/+$/, ''));
      store.putSync(KEY_APP_TOKEN, appToken.trim());
      store.putSync(KEY_MODEL, model.trim());
      store.flush();
    } catch (error) {
      return;
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

  static saveVideos(context: common.Context, videos: VideoStudyItem[]): void {
    try {
      const store: preferences.Preferences = LearningPreferences.store(context);
      store.putSync(KEY_VIDEOS, JSON.stringify(videos));
      store.flush();
    } catch (error) {
      return;
    }
  }
}
