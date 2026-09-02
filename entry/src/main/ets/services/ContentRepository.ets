import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import {
  ContentManifest,
  GrammarIndexEntry,
  GrammarLesson,
  LearningJourney,
  LearningCatalog,
  MusicTrack,
  ReadingWork,
  VocabularyEntry
} from '../model/ContentModels';

export class ContentRepository {
  static loadCatalog(context: common.Context): LearningCatalog {
    return JSON.parse(ContentRepository.readText(context, 'content/catalog.json')) as LearningCatalog;
  }

  static loadManifest(context: common.Context): ContentManifest {
    return JSON.parse(ContentRepository.readText(context, 'content/manifest.json')) as ContentManifest;
  }

  static loadJourneys(context: common.Context): LearningJourney[] {
    return JSON.parse(ContentRepository.readText(context, 'content/journeys.json')) as LearningJourney[];
  }

  static loadMusicTracks(context: common.Context): MusicTrack[] {
    return JSON.parse(ContentRepository.readText(context, 'content/music.json')) as MusicTrack[];
  }

  static loadReadingWorks(context: common.Context): ReadingWork[] {
    return JSON.parse(ContentRepository.readText(context, 'content/reading.json')) as ReadingWork[];
  }

  static loadGrammarIndex(context: common.Context): GrammarIndexEntry[] {
    return JSON.parse(ContentRepository.readText(context, 'content/grammar/index.json')) as GrammarIndexEntry[];
  }

  static loadGrammarLesson(context: common.Context, id: string): GrammarLesson {
    return JSON.parse(ContentRepository.readText(context, `content/grammar/lessons/${id}.json`)) as GrammarLesson;
  }

  static loadVocabulary(context: common.Context, level: string): VocabularyEntry[] {
    return JSON.parse(ContentRepository.readText(context,
      `content/vocabulary/${ContentRepository.vocabularyFileName(level)}.json`)) as VocabularyEntry[];
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
