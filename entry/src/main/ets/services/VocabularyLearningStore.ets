import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { VocabularyEntry } from '../model/ContentModels';
import { PracticeMessage } from '../model/DeepSeekModels';
import {
  DEFAULT_COURSE_SCOPE,
  DEFAULT_SUPPORT_LOCALE,
  DEFAULT_TARGET_LOCALE,
  LearningCourseScope,
  SyncConversationRecord,
  SyncLearnedItemRecord
} from '../model/SyncModels';
import { LearningSyncStore } from './LearningSyncStore';

const ARCHIVE_DIRECTORY: string = 'kotoba_learning';
const COURSES_DIRECTORY: string = 'courses';
const CONVERSATION_DIRECTORY: string = 'conversations';
const LEGACY_CONVERSATION_DIRECTORY: string = 'word_conversations';
const LEARNED_WORDS_FILE: string = 'learned_words.json';

export interface LearnedVocabularySnapshot {
  id: string;
  level: string;
  word: string;
  reading: string;
  meaning: string;
}

export interface StoredConversationSnapshot {
  conversationKey: string;
  messages: PracticeMessage[];
}

export class VocabularyLearningStore {
  static loadLearnedWords(context: common.Context,
    courseId: string = DEFAULT_COURSE_SCOPE.courseId): LearnedVocabularySnapshot[] {
    const path: string = VocabularyLearningStore.readableLearnedWordsPath(context, courseId);
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

  static saveLearnedWords(context: common.Context, words: LearnedVocabularySnapshot[],
    mirrorToSyncStore: boolean = true, scope: LearningCourseScope = DEFAULT_COURSE_SCOPE): boolean {
    const directory: string = VocabularyLearningStore.ensureCourseDirectory(context, scope.courseId);
    if (directory.length === 0) {
      return false;
    }
    const saved: boolean = VocabularyLearningStore.writeText(
      `${directory}/${LEARNED_WORDS_FILE}`, JSON.stringify(words));
    if (saved && mirrorToSyncStore) {
      const now: number = Date.now();
      const records: SyncLearnedItemRecord[] = [];
      for (let index: number = 0; index < words.length; index++) {
        const word: LearnedVocabularySnapshot = words[index];
        records.push({
          recordId: `${scope.courseId}:learned:vocabulary:${word.id}`,
          courseId: scope.courseId,
          targetLocale: scope.targetLocale,
          itemType: 'vocabulary',
          itemId: word.id,
          level: word.level,
          learnedAt: now,
          updatedAt: now,
          deleted: false
        });
      }
      LearningSyncStore.replaceLearnedItems(context, records, scope);
    }
    return saved;
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

  static loadConversation(context: common.Context, conversationKey: string,
    courseId: string = DEFAULT_COURSE_SCOPE.courseId): PracticeMessage[] {
    const path: string = VocabularyLearningStore.readableConversationPath(context, conversationKey, courseId);
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
            revision: message.revision,
            languageTag: message.languageTag,
            createdAt: message.createdAt
          });
        }
      }
      return result;
    } catch (error) {
      return [];
    }
  }

  static saveConversation(context: common.Context, conversationKey: string,
    messages: PracticeMessage[], targetLocale: string = DEFAULT_TARGET_LOCALE,
    supportLocale: string = DEFAULT_SUPPORT_LOCALE, courseId: string = DEFAULT_COURSE_SCOPE.courseId,
    mirrorToSyncStore: boolean = true): boolean {
    const path: string = VocabularyLearningStore.writableConversationPath(context, conversationKey, courseId);
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
    const saved: boolean = VocabularyLearningStore.writeText(path, JSON.stringify(stored));
    if (saved && mirrorToSyncStore) {
      const topicType: string = VocabularyLearningStore.topicType(conversationKey);
      const topicId: string = VocabularyLearningStore.topicId(conversationKey, topicType);
      const conversation: SyncConversationRecord = {
        recordId: `${courseId}:conversation:${topicType}:${topicId}`,
        courseId: courseId,
        targetLocale: targetLocale,
        supportLocale: supportLocale,
        topicType: topicType,
        topicId: topicId,
        updatedAt: Date.now(),
        deleted: false
      };
      LearningSyncStore.saveConversation(context, conversation, stored);
    }
    return saved;
  }

  static loadAllConversations(context: common.Context,
    courseId: string = DEFAULT_COURSE_SCOPE.courseId): StoredConversationSnapshot[] {
    try {
      const directories: string[] = [
        `${VocabularyLearningStore.courseDirectory(context, courseId)}/${CONVERSATION_DIRECTORY}`
      ];
      if (courseId === DEFAULT_COURSE_SCOPE.courseId) {
        directories.push(`${VocabularyLearningStore.archiveDirectory(context)}/${LEGACY_CONVERSATION_DIRECTORY}`);
      }
      const result: StoredConversationSnapshot[] = [];
      const seen: Set<string> = new Set<string>();
      for (let directoryIndex: number = 0; directoryIndex < directories.length; directoryIndex++) {
        if (!VocabularyLearningStore.exists(directories[directoryIndex])) {
          continue;
        }
        const files: string[] = fileIo.listFileSync(directories[directoryIndex]);
        for (let index: number = 0; index < files.length; index++) {
          const filename: string = files[index];
          if (!filename.endsWith('.json')) {
            continue;
          }
          const conversationKey: string = filename.slice(0, filename.length - 5);
          if (seen.has(conversationKey)) {
            continue;
          }
          seen.add(conversationKey);
          const messages: PracticeMessage[] = VocabularyLearningStore.loadConversation(
            context, conversationKey, courseId);
          if (messages.length > 0) {
            result.push({ conversationKey: conversationKey, messages: messages });
          }
        }
      }
      return result;
    } catch (error) {
      return [];
    }
  }

  static conversationKey(topicType: string, topicId: string): string {
    return `${topicType}-${topicId}`;
  }

  static conversationCount(context: common.Context, conversationKey: string,
    courseId: string = DEFAULT_COURSE_SCOPE.courseId): number {
    return VocabularyLearningStore.loadConversation(context, conversationKey, courseId).length;
  }

  private static archiveDirectory(context: common.Context): string {
    return `${context.filesDir}/${ARCHIVE_DIRECTORY}`;
  }

  private static ensureDirectory(directory: string): string {
    try {
      if (!fileIo.accessSync(directory)) {
        fileIo.mkdirSync(directory, true);
      }
      return directory;
    } catch (error) {
      return '';
    }
  }

  private static courseDirectory(context: common.Context, courseId: string): string {
    return `${VocabularyLearningStore.archiveDirectory(context)}/${COURSES_DIRECTORY}/` +
      VocabularyLearningStore.safeKey(courseId);
  }

  private static ensureCourseDirectory(context: common.Context, courseId: string): string {
    return VocabularyLearningStore.ensureDirectory(VocabularyLearningStore.courseDirectory(context, courseId));
  }

  private static readableLearnedWordsPath(context: common.Context, courseId: string): string {
    const scoped: string = `${VocabularyLearningStore.courseDirectory(context, courseId)}/${LEARNED_WORDS_FILE}`;
    if (VocabularyLearningStore.exists(scoped)) {
      return scoped;
    }
    if (courseId === DEFAULT_COURSE_SCOPE.courseId) {
      return `${VocabularyLearningStore.archiveDirectory(context)}/${LEARNED_WORDS_FILE}`;
    }
    return scoped;
  }

  private static readableConversationPath(context: common.Context, conversationKey: string,
    courseId: string): string {
    const safeKey: string = VocabularyLearningStore.safeKey(conversationKey);
    if (safeKey.length === 0) {
      return '';
    }
    const scoped: string = `${VocabularyLearningStore.courseDirectory(context, courseId)}/` +
      `${CONVERSATION_DIRECTORY}/${safeKey}.json`;
    if (VocabularyLearningStore.exists(scoped)) {
      return scoped;
    }
    if (courseId === DEFAULT_COURSE_SCOPE.courseId) {
      return `${VocabularyLearningStore.archiveDirectory(context)}/` +
        `${LEGACY_CONVERSATION_DIRECTORY}/${safeKey}.json`;
    }
    return scoped;
  }

  private static writableConversationPath(context: common.Context, conversationKey: string,
    courseId: string): string {
    const safeKey: string = VocabularyLearningStore.safeKey(conversationKey);
    if (safeKey.length === 0) {
      return '';
    }
    const course: string = VocabularyLearningStore.ensureCourseDirectory(context, courseId);
    if (course.length === 0) {
      return '';
    }
    const directory: string = VocabularyLearningStore.ensureDirectory(`${course}/${CONVERSATION_DIRECTORY}`);
    return directory.length === 0 ? '' : `${directory}/${safeKey}.json`;
  }

  private static safeKey(value: string): string {
    return value.replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 72);
  }

  private static exists(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (error) {
      return false;
    }
  }

  private static topicType(conversationKey: string): string {
    const separator: number = conversationKey.indexOf('-');
    if (separator <= 0) {
      return 'content';
    }
    return conversationKey.slice(0, separator);
  }

  private static topicId(conversationKey: string, topicType: string): string {
    const prefix: string = `${topicType}-`;
    return conversationKey.startsWith(prefix) ? conversationKey.slice(prefix.length) : conversationKey;
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
