import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import {
  ContentManifest,
  LearningJourney,
  LearningCatalog,
  MusicTrack,
  ReadingWork,
  VocabularyEntry
} from '../model/ContentModels';
import { GrammarWork } from '../model/GrammarModels';
import { GrammarCloudStore } from './GrammarCloudStore';
import { ReadingCloudStore } from './ReadingCloudStore';

export class ContentRepository {
  static loadCatalog(context: common.Context): LearningCatalog {
    return JSON.parse(ContentRepository.readText(context, 'catalog.json')) as LearningCatalog;
  }

  static loadManifest(context: common.Context): ContentManifest {
    return JSON.parse(ContentRepository.readText(context, 'manifest.json')) as ContentManifest;
  }

  static loadJourneys(context: common.Context): LearningJourney[] {
    return JSON.parse(ContentRepository.readText(context, 'journeys.json')) as LearningJourney[];
  }

  static loadMusicTracks(context: common.Context): MusicTrack[] {
    return JSON.parse(ContentRepository.readText(context, 'music.json')) as MusicTrack[];
  }

  static loadReadingWorks(context: common.Context): ReadingWork[] {
    return ReadingCloudStore.cached(context);
  }

  static async loadReadingWorksAsync(context: common.Context): Promise<ReadingWork[]> {
    return await ReadingCloudStore.cachedAsync(context);
  }

  static async prefetchReadings(context: common.Context): Promise<ReadingWork[]> {
    return await ReadingCloudStore.refresh(context);
  }

  static loadGrammarWorks(context: common.Context): GrammarWork[] {
    return GrammarCloudStore.cached(context);
  }

  static async loadGrammarWorksAsync(context: common.Context): Promise<GrammarWork[]> {
    return await GrammarCloudStore.cachedAsync(context);
  }

  static async prefetchGrammar(context: common.Context): Promise<GrammarWork[]> {
    return await GrammarCloudStore.refresh(context);
  }

  static loadVocabulary(context: common.Context, level: string): VocabularyEntry[] {
    return JSON.parse(ContentRepository.readText(context,
      `vocabulary/${ContentRepository.vocabularyFileName(level)}.json`)) as VocabularyEntry[];
  }

  private static vocabularyFileName(level: string): string {
    switch (level) {
      case '日常':
        return 'extra-daily';
      case '一般':
        return 'extra-general';
      case '补遗':
        return 'extra-supplement';
      default:
        return level.toLowerCase();
    }
  }

  private static readText(context: common.Context, path: string): string {
    try {
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(path);
      return util.TextDecoder.create('utf-8').decodeToString(bytes);
    } catch (error) {
      throw new Error(`Unable to read bundled content: ${path}`);
    }
  }
}
