import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { VocabularyEntry } from '../model/ContentModels';
import { PracticeMessage } from '../model/DeepSeekModels';

const ARCHIVE_DIRECTORY: string = 'kotoba_learning';
const CONVERSATION_DIRECTORY: string = 'word_conversations';
const LEARNED_WORDS_FILE: string = 'learned_words.json';

export interface LearnedVocabularySnapshot {
  id: string;
  level: string;
  word: string;
  reading: string;
  meaning: string;
}

export class VocabularyLearningStore {
  static loadLearnedWords(context: common.Context): LearnedVocabularySnapshot[] {
    const path: string = `${VocabularyLearningStore.archiveDirectory(context)}/${LEARNED_WORDS_FILE}`;
    try {
      if (!fileIo.accessSync(path)) {
        return [];
      }
      const stored: LearnedVocabularySnapshot[] =
        JSON.parse(fileIo.readTextSync(path)) as LearnedVocabularySnapshot[];
      const result: LearnedVocabularySnapshot[] = [];
      for (let index: number = 0; index < stored.length; index++) {
        const item: LearnedVocabularySnapshot = stored[index];
        if (item.id.length > 0 && item.word.length > 0) {
          result.push(item);
        }
      }
      return result;
    } catch (error) {
      return [];
    }
  }

  static saveLearnedWords(context: common.Context, words: LearnedVocabularySnapshot[]): boolean {
    const directory: string = VocabularyLearningStore.ensureArchiveDirectory(context);
    if (directory.length === 0) {
      return false;
    }
    return VocabularyLearningStore.writeText(`${directory}/${LEARNED_WORDS_FILE}`, JSON.stringify(words));
  }

  static snapshot(item: VocabularyEntry): LearnedVocabularySnapshot {
    return {
      id: item.id,
      level: item.level,
      word: item.word,
      reading: item.reading,
      meaning: item.meanings.length > 0 ? item.meanings[0] : ''
    };
  }

  static loadConversation(context: common.Context, conversationKey: string): PracticeMessage[] {
    const path: string = VocabularyLearningStore.conversationPath(context, conversationKey, false);
    if (path.length === 0) {
      return [];
    }
    try {
      if (!fileIo.accessSync(path)) {
        return [];
      }
      const stored: PracticeMessage[] = JSON.parse(fileIo.readTextSync(path)) as PracticeMessage[];
      const result: PracticeMessage[] = [];
      for (let index: number = 0; index < stored.length; index++) {
        const message: PracticeMessage = stored[index];
        if ((message.role === 'user' || message.role === 'assistant') && message.text.length > 0) {
          result.push({
            id: message.id,
            role: message.role,
            text: message.text,
            revision: message.revision
          });
        }
      }
      return result;
    } catch (error) {
      return [];
    }
  }

  static saveConversation(context: common.Context, conversationKey: string,
    messages: PracticeMessage[]): boolean {
    const path: string = VocabularyLearningStore.conversationPath(context, conversationKey, true);
    if (path.length === 0) {
      return false;
    }
    const stored: PracticeMessage[] = [];
    for (let index: number = 0; index < messages.length; index++) {
      const message: PracticeMessage = messages[index];
      if ((message.role === 'user' || message.role === 'assistant') && message.text.length > 0) {
        stored.push(message);
      }
    }
    return VocabularyLearningStore.writeText(path, JSON.stringify(stored));
  }

  static conversationCount(context: common.Context, conversationKey: string): number {
    return VocabularyLearningStore.loadConversation(context, conversationKey).length;
  }

  private static archiveDirectory(context: common.Context): string {
    return `${context.filesDir}/${ARCHIVE_DIRECTORY}`;
  }

  private static ensureArchiveDirectory(context: common.Context): string {
    const directory: string = VocabularyLearningStore.archiveDirectory(context);
    try {
      if (!fileIo.accessSync(directory)) {
        fileIo.mkdirSync(directory, true);
      }
      return directory;
    } catch (error) {
      return '';
    }
  }

  private static conversationPath(context: common.Context, conversationKey: string,
    createDirectory: boolean): string {
    const safeKey: string = VocabularyLearningStore.safeKey(conversationKey);
    if (safeKey.length === 0) {
      return '';
    }
    const archive: string = createDirectory ? VocabularyLearningStore.ensureArchiveDirectory(context) :
      VocabularyLearningStore.archiveDirectory(context);
    if (archive.length === 0) {
      return '';
    }
    const directory: string = `${archive}/${CONVERSATION_DIRECTORY}`;
    if (createDirectory) {
      try {
        if (!fileIo.accessSync(directory)) {
          fileIo.mkdirSync(directory, true);
        }
      } catch (error) {
        return '';
      }
    }
    return `${directory}/${safeKey}.json`;
  }

  private static safeKey(value: string): string {
    return value.replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 72);
  }

  private static writeText(path: string, content: string): boolean {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
      return true;
    } catch (error) {
      return false;
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (error) {
          return false;
        }
      }
    }
  }
}
