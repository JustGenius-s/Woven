import { PracticeMessage } from './DeepSeekModels';

export const DEFAULT_COURSE_ID: string = 'japanese-core-v1';
export const DEFAULT_TARGET_LOCALE: string = 'ja-JP';
export const DEFAULT_SUPPORT_LOCALE: string = 'zh-Hans';

export interface LearningCourseScope {
  courseId: string;
  targetLocale: string;
  supportLocale: string;
}

export const DEFAULT_COURSE_SCOPE: LearningCourseScope = {
  courseId: DEFAULT_COURSE_ID,
  targetLocale: DEFAULT_TARGET_LOCALE,
  supportLocale: DEFAULT_SUPPORT_LOCALE
};

export interface SyncProgressRecord {
  recordId: string;
  courseId: string;
  targetLocale: string;
  supportLocale: string;
  kind: string;
  itemId: string;
  numericValue: number;
  textValue: string;
  updatedAt: number;
  deleted: boolean;
}

export interface SyncLearnedItemRecord {
  recordId: string;
  courseId: string;
  targetLocale: string;
  itemType: string;
  itemId: string;
  level: string;
  learnedAt: number;
  updatedAt: number;
  deleted: boolean;
}

export interface SyncConversationRecord {
  recordId: string;
  courseId: string;
  targetLocale: string;
  supportLocale: string;
  topicType: string;
  topicId: string;
  updatedAt: number;
  deleted: boolean;
}

export interface SyncConversationSeed {
  conversation: SyncConversationRecord;
  messages: PracticeMessage[];
}

export interface LearningSyncSeed {
  progress: SyncProgressRecord[];
  learnedItems: SyncLearnedItemRecord[];
  conversations: SyncConversationSeed[];
}

export interface LearningSyncSnapshot {
  progress: SyncProgressRecord[];
  learnedItems: SyncLearnedItemRecord[];
  conversations: SyncConversationSeed[];
}

export enum HuaweiAccountPhase {
  SIGNED_OUT = 0,
  CHECKING = 1,
  SIGNED_IN = 2,
  NEEDS_CONFIGURATION = 3,
  ERROR = 4
}

export interface HuaweiAccountSnapshot {
  phase: HuaweiAccountPhase;
  unionId: string;
  openId: string;
  detail: string;
}

export enum CloudSyncPhase {
  LOCAL_ONLY = 0,
  READY = 1,
  SYNCING = 2,
  SYNCED = 3,
  NEEDS_CONFIGURATION = 4,
  ERROR = 5
}

export interface CloudSyncSnapshot {
  phase: CloudSyncPhase;
  lastSyncedAt: number;
  detail: string;
}
