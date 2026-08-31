import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PracticeMessage } from '../model/DeepSeekModels';
import {
  DEFAULT_COURSE_SCOPE,
  LearningCourseScope,
  LearningSyncSeed,
  LearningSyncSnapshot,
  SyncConversationRecord,
  SyncConversationSeed,
  SyncLearnedItemRecord,
  SyncProgressRecord
} from '../model/SyncModels';

const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'LearningSyncStore';
const DATABASE_NAME: string = 'kotoba_learning_sync.db';
const DATABASE_SECURITY_LEVEL: relationalStore.SecurityLevel = relationalStore.SecurityLevel.S2;
const TABLE_METADATA: string = 'sync_metadata';
const TABLE_PROGRESS: string = 'learning_progress';
const TABLE_LEARNED_ITEM: string = 'learned_item';
const TABLE_CONVERSATION: string = 'conversation';
const TABLE_MESSAGE: string = 'message';
const META_LEGACY_MIGRATED: string = 'legacy_migrated_v1';
const META_LAST_SYNCED_AT: string = 'last_synced_at';

const CLOUD_TABLES: string[] = [
  TABLE_PROGRESS,
  TABLE_LEARNED_ITEM,
  TABLE_CONVERSATION,
  TABLE_MESSAGE
];

interface StoredMessageRow {
  conversationId: string;
  message: PracticeMessage;
}

export class LearningSyncStore {
  private static storePromise: Promise<relationalStore.RdbStore> | undefined = undefined;

  static async initialize(context: common.Context, seed: LearningSyncSeed): Promise<number> {
    const store: relationalStore.RdbStore = await LearningSyncStore.store(context);
    const migrated: string = await LearningSyncStore.metadata(store, META_LEGACY_MIGRATED);
    if (migrated !== '1') {
      await LearningSyncStore.importSeed(store, seed);
      await LearningSyncStore.setMetadata(store, META_LEGACY_MIGRATED, '1');
      hilog.info(LOG_DOMAIN, LOG_TAG,
        'Legacy learning state migrated progress=%{public}d items=%{public}d conversations=%{public}d',
        seed.progress.length, seed.learnedItems.length, seed.conversations.length);
    }
    const lastSyncedAt: string = await LearningSyncStore.metadata(store, META_LAST_SYNCED_AT);
    const parsed: number = Number(lastSyncedAt);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  static upsertProgress(context: common.Context, record: SyncProgressRecord): void {
    LearningSyncStore.store(context)
      .then((store: relationalStore.RdbStore) => LearningSyncStore.writeProgress(store, record))
      .catch((error: Error) => LearningSyncStore.logFailure('upsert progress', error));
  }

  static async upsertProgressNow(context: common.Context, record: SyncProgressRecord): Promise<void> {
    await LearningSyncStore.writeProgress(await LearningSyncStore.store(context), record);
  }

  static replaceLearnedItems(context: common.Context, records: SyncLearnedItemRecord[],
    scope: LearningCourseScope = DEFAULT_COURSE_SCOPE): void {
    LearningSyncStore.store(context)
      .then(async (store: relationalStore.RdbStore) => {
        const activeIds: Set<string> = new Set<string>();
        const existingByItemId: Map<string, SyncLearnedItemRecord> = new Map<string, SyncLearnedItemRecord>();
        for (let index: number = 0; index < records.length; index++) {
          activeIds.add(records[index].itemId);
        }

        const existing: SyncLearnedItemRecord[] = await LearningSyncStore.readLearnedItems(store, false);
        const now: number = Date.now();
        for (let index: number = 0; index < existing.length; index++) {
          const item: SyncLearnedItemRecord = existing[index];
          if (item.courseId === scope.courseId && item.itemType === 'vocabulary') {
            existingByItemId.set(item.itemId, item);
          }
          if (item.courseId === scope.courseId && item.itemType === 'vocabulary' &&
            !item.deleted && !activeIds.has(item.itemId)) {
            await LearningSyncStore.writeLearnedItem(store, {
              recordId: item.recordId,
              courseId: item.courseId,
              targetLocale: item.targetLocale,
              itemType: item.itemType,
              itemId: item.itemId,
              level: item.level,
              learnedAt: item.learnedAt,
              updatedAt: now,
              deleted: true
            });
          }
        }
        for (let index: number = 0; index < records.length; index++) {
          const record: SyncLearnedItemRecord = records[index];
          const stored: SyncLearnedItemRecord | undefined = existingByItemId.get(record.itemId);
          if (stored === undefined || stored.deleted || stored.level !== record.level ||
            stored.targetLocale !== record.targetLocale) {
            await LearningSyncStore.writeLearnedItem(store, {
              recordId: record.recordId,
              courseId: record.courseId,
              targetLocale: record.targetLocale,
              itemType: record.itemType,
              itemId: record.itemId,
              level: record.level,
              learnedAt: stored === undefined || stored.deleted ? record.learnedAt : stored.learnedAt,
              updatedAt: record.updatedAt,
              deleted: false
            });
          }
        }
      })
      .catch((error: Error) => LearningSyncStore.logFailure('replace learned items', error));
  }

  static saveConversation(context: common.Context, conversation: SyncConversationRecord,
    messages: PracticeMessage[]): void {
    LearningSyncStore.store(context)
      .then(async (store: relationalStore.RdbStore) => {
        await LearningSyncStore.writeConversation(store, conversation);
        for (let index: number = 0; index < messages.length; index++) {
          const message: PracticeMessage = messages[index];
          if (message.text.length > 0) {
            await LearningSyncStore.writeMessage(store, conversation, message);
          }
        }
      })
      .catch((error: Error) => LearningSyncStore.logFailure('save conversation', error));
  }

  static async syncNow(context: common.Context): Promise<LearningSyncSnapshot> {
    const store: relationalStore.RdbStore = await LearningSyncStore.store(context);
    await store.setDistributedTables(
      CLOUD_TABLES,
      relationalStore.DistributedType.DISTRIBUTED_CLOUD,
      { autoSync: true, enableCloud: true }
    );
    await LearningSyncStore.runCloudSync(store, relationalStore.SyncMode.SYNC_MODE_TIME_FIRST);
    const timestamp: number = Date.now();
    await LearningSyncStore.setMetadata(store, META_LAST_SYNCED_AT, timestamp.toString());
    return LearningSyncStore.readSnapshotFromStore(store);
  }

  static async pushMergedState(context: common.Context): Promise<void> {
    const store: relationalStore.RdbStore = await LearningSyncStore.store(context);
    await LearningSyncStore.runCloudSync(store, relationalStore.SyncMode.SYNC_MODE_NATIVE_FIRST);
    await LearningSyncStore.setMetadata(store, META_LAST_SYNCED_AT, Date.now().toString());
  }

  static async readSnapshot(context: common.Context): Promise<LearningSyncSnapshot> {
    return LearningSyncStore.readSnapshotFromStore(await LearningSyncStore.store(context));
  }

  private static async store(context: common.Context): Promise<relationalStore.RdbStore> {
    if (LearningSyncStore.storePromise === undefined) {
      LearningSyncStore.storePromise = LearningSyncStore.open(context).catch((error: Error) => {
        LearningSyncStore.storePromise = undefined;
        throw error;
      });
    }
    return LearningSyncStore.storePromise;
  }

  private static async open(context: common.Context): Promise<relationalStore.RdbStore> {
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, {
      name: DATABASE_NAME,
      securityLevel: DATABASE_SECURITY_LEVEL
    });
    await LearningSyncStore.createSchema(store);
    return store;
  }

  private static async createSchema(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql(`CREATE TABLE IF NOT EXISTS ${TABLE_METADATA} (` +
      'meta_key TEXT PRIMARY KEY NOT NULL, meta_value TEXT NOT NULL)');
    await store.executeSql(`CREATE TABLE IF NOT EXISTS ${TABLE_PROGRESS} (` +
      'record_id TEXT PRIMARY KEY NOT NULL, course_id TEXT NOT NULL, target_locale TEXT NOT NULL, ' +
      'support_locale TEXT NOT NULL, kind TEXT NOT NULL, item_id TEXT NOT NULL, numeric_value INTEGER NOT NULL, ' +
      'text_value TEXT NOT NULL, updated_at INTEGER NOT NULL, deleted INTEGER NOT NULL)');
    await store.executeSql(`CREATE TABLE IF NOT EXISTS ${TABLE_LEARNED_ITEM} (` +
      'record_id TEXT PRIMARY KEY NOT NULL, course_id TEXT NOT NULL, target_locale TEXT NOT NULL, ' +
      'item_type TEXT NOT NULL, item_id TEXT NOT NULL, level TEXT NOT NULL, learned_at INTEGER NOT NULL, ' +
      'updated_at INTEGER NOT NULL, deleted INTEGER NOT NULL)');
    await store.executeSql(`CREATE TABLE IF NOT EXISTS ${TABLE_CONVERSATION} (` +
      'record_id TEXT PRIMARY KEY NOT NULL, course_id TEXT NOT NULL, target_locale TEXT NOT NULL, ' +
      'support_locale TEXT NOT NULL, topic_type TEXT NOT NULL, topic_id TEXT NOT NULL, ' +
      'updated_at INTEGER NOT NULL, deleted INTEGER NOT NULL)');
    await store.executeSql(`CREATE TABLE IF NOT EXISTS ${TABLE_MESSAGE} (` +
      'record_id TEXT PRIMARY KEY NOT NULL, conversation_id TEXT NOT NULL, course_id TEXT NOT NULL, ' +
      'target_locale TEXT NOT NULL, role TEXT NOT NULL, body TEXT NOT NULL, language_tag TEXT NOT NULL, ' +
      'created_at INTEGER NOT NULL, revision INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted INTEGER NOT NULL)');
  }

  private static async importSeed(store: relationalStore.RdbStore, seed: LearningSyncSeed): Promise<void> {
    for (let index: number = 0; index < seed.progress.length; index++) {
      await LearningSyncStore.writeProgress(store, seed.progress[index]);
    }
    for (let index: number = 0; index < seed.learnedItems.length; index++) {
      await LearningSyncStore.writeLearnedItem(store, seed.learnedItems[index]);
    }
    for (let index: number = 0; index < seed.conversations.length; index++) {
      const seedConversation: SyncConversationSeed = seed.conversations[index];
      await LearningSyncStore.writeConversation(store, seedConversation.conversation);
      for (let messageIndex: number = 0; messageIndex < seedConversation.messages.length; messageIndex++) {
        const message: PracticeMessage = seedConversation.messages[messageIndex];
        if (message.text.length > 0) {
          await LearningSyncStore.writeMessage(store, seedConversation.conversation, message);
        }
      }
    }
  }

  private static async writeProgress(store: relationalStore.RdbStore,
    record: SyncProgressRecord): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      record_id: record.recordId,
      course_id: record.courseId,
      target_locale: record.targetLocale,
      support_locale: record.supportLocale,
      kind: record.kind,
      item_id: record.itemId,
      numeric_value: record.numericValue,
      text_value: record.textValue,
      updated_at: record.updatedAt,
      deleted: record.deleted ? 1 : 0
    };
    await store.insert(TABLE_PROGRESS, values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private static async writeLearnedItem(store: relationalStore.RdbStore,
    record: SyncLearnedItemRecord): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      record_id: record.recordId,
      course_id: record.courseId,
      target_locale: record.targetLocale,
      item_type: record.itemType,
      item_id: record.itemId,
      level: record.level,
      learned_at: record.learnedAt,
      updated_at: record.updatedAt,
      deleted: record.deleted ? 1 : 0
    };
    await store.insert(TABLE_LEARNED_ITEM, values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private static async writeConversation(store: relationalStore.RdbStore,
    record: SyncConversationRecord): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      record_id: record.recordId,
      course_id: record.courseId,
      target_locale: record.targetLocale,
      support_locale: record.supportLocale,
      topic_type: record.topicType,
      topic_id: record.topicId,
      updated_at: record.updatedAt,
      deleted: record.deleted ? 1 : 0
    };
    await store.insert(TABLE_CONVERSATION, values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private static async writeMessage(store: relationalStore.RdbStore,
    conversation: SyncConversationRecord, message: PracticeMessage): Promise<void> {
    const createdAt: number = message.createdAt === undefined ? LearningSyncStore.timestampFromId(message.id) :
      message.createdAt;
    const languageTag: string = message.languageTag === undefined || message.languageTag.length === 0 ?
      conversation.targetLocale : message.languageTag;
    const values: relationalStore.ValuesBucket = {
      record_id: `${conversation.recordId}:${message.id}`,
      conversation_id: conversation.recordId,
      course_id: conversation.courseId,
      target_locale: conversation.targetLocale,
      role: message.role,
      body: message.text,
      language_tag: languageTag,
      created_at: createdAt,
      revision: message.revision,
      updated_at: createdAt + message.revision,
      deleted: 0
    };
    await store.insert(TABLE_MESSAGE, values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private static async metadata(store: relationalStore.RdbStore, key: string): Promise<string> {
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE_METADATA);
    predicates.equalTo('meta_key', key);
    const result: relationalStore.ResultSet = await store.query(predicates, ['meta_value']);
    try {
      return result.goToNextRow() ? result.getString(result.getColumnIndex('meta_value')) : '';
    } finally {
      result.close();
    }
  }

  private static async setMetadata(store: relationalStore.RdbStore, key: string, value: string): Promise<void> {
    const values: relationalStore.ValuesBucket = { meta_key: key, meta_value: value };
    await store.insert(TABLE_METADATA, values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private static async readSnapshotFromStore(store: relationalStore.RdbStore): Promise<LearningSyncSnapshot> {
    const conversations: SyncConversationRecord[] = await LearningSyncStore.readConversations(store);
    const messageRows: StoredMessageRow[] = await LearningSyncStore.readMessages(store);
    const conversationSeeds: SyncConversationSeed[] = [];
    for (let index: number = 0; index < conversations.length; index++) {
      const conversation: SyncConversationRecord = conversations[index];
      const messages: PracticeMessage[] = [];
      for (let messageIndex: number = 0; messageIndex < messageRows.length; messageIndex++) {
        if (messageRows[messageIndex].conversationId === conversation.recordId) {
          messages.push(messageRows[messageIndex].message);
        }
      }
      messages.sort((left: PracticeMessage, right: PracticeMessage) =>
        (left.createdAt ?? 0) - (right.createdAt ?? 0));
      conversationSeeds.push({ conversation: conversation, messages: messages });
    }
    return {
      progress: await LearningSyncStore.readProgress(store),
      learnedItems: await LearningSyncStore.readLearnedItems(store, true),
      conversations: conversationSeeds
    };
  }

  private static async readProgress(store: relationalStore.RdbStore): Promise<SyncProgressRecord[]> {
    const result: relationalStore.ResultSet = await store.query(new relationalStore.RdbPredicates(TABLE_PROGRESS));
    const records: SyncProgressRecord[] = [];
    try {
      while (result.goToNextRow()) {
        records.push({
          recordId: result.getString(result.getColumnIndex('record_id')),
          courseId: result.getString(result.getColumnIndex('course_id')),
          targetLocale: result.getString(result.getColumnIndex('target_locale')),
          supportLocale: result.getString(result.getColumnIndex('support_locale')),
          kind: result.getString(result.getColumnIndex('kind')),
          itemId: result.getString(result.getColumnIndex('item_id')),
          numericValue: result.getLong(result.getColumnIndex('numeric_value')),
          textValue: result.getString(result.getColumnIndex('text_value')),
          updatedAt: result.getLong(result.getColumnIndex('updated_at')),
          deleted: result.getLong(result.getColumnIndex('deleted')) === 1
        });
      }
    } finally {
      result.close();
    }
    return records;
  }

  private static async readLearnedItems(store: relationalStore.RdbStore,
    onlyActive: boolean): Promise<SyncLearnedItemRecord[]> {
    const result: relationalStore.ResultSet = await store.query(new relationalStore.RdbPredicates(TABLE_LEARNED_ITEM));
    const records: SyncLearnedItemRecord[] = [];
    try {
      while (result.goToNextRow()) {
        const deleted: boolean = result.getLong(result.getColumnIndex('deleted')) === 1;
        if (!onlyActive || !deleted) {
          records.push({
            recordId: result.getString(result.getColumnIndex('record_id')),
            courseId: result.getString(result.getColumnIndex('course_id')),
            targetLocale: result.getString(result.getColumnIndex('target_locale')),
            itemType: result.getString(result.getColumnIndex('item_type')),
            itemId: result.getString(result.getColumnIndex('item_id')),
            level: result.getString(result.getColumnIndex('level')),
            learnedAt: result.getLong(result.getColumnIndex('learned_at')),
            updatedAt: result.getLong(result.getColumnIndex('updated_at')),
            deleted: deleted
          });
        }
      }
    } finally {
      result.close();
    }
    return records;
  }

  private static async readConversations(store: relationalStore.RdbStore): Promise<SyncConversationRecord[]> {
    const result: relationalStore.ResultSet = await store.query(new relationalStore.RdbPredicates(TABLE_CONVERSATION));
    const records: SyncConversationRecord[] = [];
    try {
      while (result.goToNextRow()) {
        if (result.getLong(result.getColumnIndex('deleted')) === 0) {
          records.push({
            recordId: result.getString(result.getColumnIndex('record_id')),
            courseId: result.getString(result.getColumnIndex('course_id')),
            targetLocale: result.getString(result.getColumnIndex('target_locale')),
            supportLocale: result.getString(result.getColumnIndex('support_locale')),
            topicType: result.getString(result.getColumnIndex('topic_type')),
            topicId: result.getString(result.getColumnIndex('topic_id')),
            updatedAt: result.getLong(result.getColumnIndex('updated_at')),
            deleted: false
          });
        }
      }
    } finally {
      result.close();
    }
    return records;
  }

  private static async readMessages(store: relationalStore.RdbStore): Promise<StoredMessageRow[]> {
    const result: relationalStore.ResultSet = await store.query(new relationalStore.RdbPredicates(TABLE_MESSAGE));
    const records: StoredMessageRow[] = [];
    try {
      while (result.goToNextRow()) {
        if (result.getLong(result.getColumnIndex('deleted')) === 0) {
          const recordId: string = result.getString(result.getColumnIndex('record_id'));
          const conversationId: string = result.getString(result.getColumnIndex('conversation_id'));
          const prefix: string = `${conversationId}:`;
          records.push({
            conversationId: conversationId,
            message: {
              id: recordId.startsWith(prefix) ? recordId.slice(prefix.length) : recordId,
              role: result.getString(result.getColumnIndex('role')),
              text: result.getString(result.getColumnIndex('body')),
              languageTag: result.getString(result.getColumnIndex('language_tag')),
              createdAt: result.getLong(result.getColumnIndex('created_at')),
              revision: result.getLong(result.getColumnIndex('revision'))
            }
          });
        }
      }
    } finally {
      result.close();
    }
    return records;
  }

  private static timestampFromId(id: string): number {
    const parts: string[] = id.split('-');
    for (let index: number = 0; index < parts.length; index++) {
      const candidate: number = Number(parts[index]);
      if (Number.isFinite(candidate) && candidate > 1000000000000) {
        return candidate;
      }
    }
    return Date.now();
  }

  private static async runCloudSync(store: relationalStore.RdbStore,
    mode: relationalStore.SyncMode): Promise<void> {
    let progressCode: relationalStore.ProgressCode = relationalStore.ProgressCode.SUCCESS;
    await store.cloudSync(mode, CLOUD_TABLES, (details: relationalStore.ProgressDetails): void => {
      if (details.schedule === relationalStore.Progress.SYNC_FINISH) {
        progressCode = details.code;
      }
    });
    if (progressCode !== relationalStore.ProgressCode.SUCCESS) {
      throw new Error(`cloud-sync-progress-${progressCode}`);
    }
  }

  private static logFailure(operation: string, error: Error): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'Unable to %{public}s: %{public}s', operation, error.message);
  }
}
