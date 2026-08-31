import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  GrammarIndexEntry,
  LearningCatalog,
  MusicTrack,
  PracticeScenario,
  ReadingWork,
  VocabularyEntry
} from '../model/ContentModels';
import { PracticeMessage } from '../model/DeepSeekModels';
import {
  CloudSyncPhase,
  CloudSyncSnapshot,
  DEFAULT_COURSE_SCOPE,
  LearningSyncSeed,
  LearningSyncSnapshot,
  SyncConversationRecord,
  SyncConversationSeed,
  SyncLearnedItemRecord,
  SyncProgressRecord
} from '../model/SyncModels';
import { ContentRepository } from './ContentRepository';
import { LearningPreferences } from './LearningPreferences';
import { LearningSyncStore } from './LearningSyncStore';
import {
  LearnedVocabularySnapshot,
  StoredConversationSnapshot,
  VocabularyLearningStore
} from './VocabularyLearningStore';

const VOCABULARY_LEVELS: string[] = ['N5', 'N4', 'N3', 'N2', 'N1'];

export class LearningSyncCoordinator {
  static async initialize(context: common.Context): Promise<CloudSyncSnapshot> {
    try {
      const lastSyncedAt: number = await LearningSyncStore.initialize(
        context, LearningSyncCoordinator.legacySeed(context));
      return {
        phase: CloudSyncPhase.READY,
        lastSyncedAt: lastSyncedAt,
        detail: ''
      };
    } catch (error) {
      return {
        phase: CloudSyncPhase.LOCAL_ONLY,
        lastSyncedAt: 0,
        detail: LearningSyncCoordinator.errorCode(error)
      };
    }
  }

  static async syncNow(context: common.Context, previousLastSyncedAt: number = 0): Promise<CloudSyncSnapshot> {
    try {
      const snapshot: LearningSyncSnapshot = await LearningSyncStore.syncNow(context);
      await LearningSyncCoordinator.applySnapshot(context, snapshot);
      await LearningSyncStore.pushMergedState(context);
      return {
        phase: CloudSyncPhase.SYNCED,
        lastSyncedAt: Date.now(),
        detail: ''
      };
    } catch (error) {
      const detail: string = LearningSyncCoordinator.errorCode(error);
      return {
        phase: LearningSyncCoordinator.needsConfiguration(detail) ?
          CloudSyncPhase.NEEDS_CONFIGURATION : CloudSyncPhase.ERROR,
        lastSyncedAt: previousLastSyncedAt,
        detail: detail
      };
    }
  }

  static saveKanaProgress(context: common.Context, key: string): void {
    LearningSyncStore.upsertProgress(context,
      LearningSyncCoordinator.progressRecord('kana.current', key, 0, ''));
  }

  static saveGrammarProgress(context: common.Context, index: number): void {
    let itemId: string = '';
    try {
      const entries: GrammarIndexEntry[] = ContentRepository.loadGrammarIndex(context);
      if (index >= 0 && index < entries.length) {
        itemId = entries[index].id;
      }
    } catch (error) {
      itemId = '';
    }
    LearningSyncStore.upsertProgress(context,
      LearningSyncCoordinator.progressRecord('grammar.current', itemId, index, ''));
  }

  static saveMusicProgress(context: common.Context, index: number): void {
    let itemId: string = '';
    try {
      const tracks: MusicTrack[] = ContentRepository.loadMusicTracks(context);
      if (index >= 0 && index < tracks.length) {
        itemId = tracks[index].id;
      }
    } catch (error) {
      itemId = '';
    }
    LearningSyncStore.upsertProgress(context,
      LearningSyncCoordinator.progressRecord('music.current', itemId, index, ''));
  }

  static saveMusicPosition(context: common.Context, trackId: string, positionMs: number): void {
    if (trackId.length === 0) {
      return;
    }
    LearningSyncStore.upsertProgress(context,
      LearningSyncCoordinator.musicPositionRecord(trackId, positionMs));
  }

  static saveReadingProgress(context: common.Context, index: number): void {
    let itemId: string = '';
    try {
      const works: ReadingWork[] = ContentRepository.loadReadingWorks(context);
      if (index >= 0 && index < works.length) {
        itemId = works[index].id;
      }
    } catch (error) {
      itemId = '';
    }
    LearningSyncStore.upsertProgress(context,
      LearningSyncCoordinator.progressRecord('reading.current', itemId, index, ''));
  }

  static saveScenarioProgress(context: common.Context, index: number): void {
    let itemId: string = '';
    try {
      const catalog: LearningCatalog = ContentRepository.loadCatalog(context);
      if (index >= 0 && index < catalog.practiceScenarios.length) {
        itemId = catalog.practiceScenarios[index].id;
      }
    } catch (error) {
      itemId = '';
    }
    LearningSyncStore.upsertProgress(context,
      LearningSyncCoordinator.progressRecord('scenario.current', itemId, index, ''));
  }

  static saveJourneyProgress(context: common.Context, journeyId: string, stage: number,
    completedMask: number): void {
    LearningSyncStore.upsertProgress(context,
      LearningSyncCoordinator.progressRecord('journey.stage', journeyId, stage, ''));
    LearningSyncStore.upsertProgress(context,
      LearningSyncCoordinator.progressRecord('journey.completed', journeyId, completedMask, ''));
  }

  private static legacySeed(context: common.Context): LearningSyncSeed {
    const now: number = Date.now();
    const progress: SyncProgressRecord[] = [];
    const journeyId: string = LearningPreferences.journeyId(context);
    progress.push(LearningSyncCoordinator.progressRecord(
      'journey.stage', journeyId, LearningPreferences.journeyStage(context), '', now));
    progress.push(LearningSyncCoordinator.progressRecord(
      'journey.completed', journeyId, LearningPreferences.journeyCompletedMask(context), '', now));
    progress.push(LearningSyncCoordinator.progressRecord(
      'kana.current', LearningPreferences.kanaKey(context), 0, '', now));
    progress.push(LearningSyncCoordinator.grammarSeed(context, now));
    progress.push(LearningSyncCoordinator.musicSeed(context, now));
    const musicPosition: SyncProgressRecord | undefined = LearningSyncCoordinator.musicPositionSeed(context, now);
    if (musicPosition !== undefined) {
      progress.push(musicPosition);
    }
    progress.push(LearningSyncCoordinator.readingSeed(context, now));
    progress.push(LearningSyncCoordinator.scenarioSeed(context, now));

    const learnedWords: LearnedVocabularySnapshot[] = VocabularyLearningStore.loadLearnedWords(context);
    const learnedItems: SyncLearnedItemRecord[] = [];
    for (let index: number = 0; index < learnedWords.length; index++) {
      const word: LearnedVocabularySnapshot = learnedWords[index];
      learnedItems.push({
        recordId: `${DEFAULT_COURSE_SCOPE.courseId}:learned:vocabulary:${word.id}`,
        courseId: DEFAULT_COURSE_SCOPE.courseId,
        targetLocale: DEFAULT_COURSE_SCOPE.targetLocale,
        itemType: 'vocabulary',
        itemId: word.id,
        level: word.level,
        learnedAt: now,
        updatedAt: now,
        deleted: false
      });
    }

    return {
      progress: progress,
      learnedItems: learnedItems,
      conversations: LearningSyncCoordinator.conversationSeeds(context, now)
    };
  }

  private static grammarSeed(context: common.Context, updatedAt: number): SyncProgressRecord {
    const index: number = LearningPreferences.grammarIndex(context);
    let itemId: string = '';
    try {
      const entries: GrammarIndexEntry[] = ContentRepository.loadGrammarIndex(context);
      if (index >= 0 && index < entries.length) {
        itemId = entries[index].id;
      }
    } catch (error) {
      itemId = '';
    }
    return LearningSyncCoordinator.progressRecord('grammar.current', itemId, index, '', updatedAt);
  }

  private static musicSeed(context: common.Context, updatedAt: number): SyncProgressRecord {
    const index: number = LearningPreferences.musicIndex(context);
    let itemId: string = '';
    try {
      const tracks: MusicTrack[] = ContentRepository.loadMusicTracks(context);
      if (index >= 0 && index < tracks.length) {
        itemId = tracks[index].id;
      }
    } catch (error) {
      itemId = '';
    }
    return LearningSyncCoordinator.progressRecord('music.current', itemId, index, '', updatedAt);
  }

  private static musicPositionSeed(context: common.Context,
    updatedAt: number): SyncProgressRecord | undefined {
    const index: number = LearningPreferences.musicIndex(context);
    try {
      const tracks: MusicTrack[] = ContentRepository.loadMusicTracks(context);
      if (index >= 0 && index < tracks.length) {
        const track: MusicTrack = tracks[index];
        return LearningSyncCoordinator.musicPositionRecord(
          track.id, LearningPreferences.musicPosition(context, track.id), updatedAt);
      }
    } catch (error) {
      return undefined;
    }
    return undefined;
  }

  private static readingSeed(context: common.Context, updatedAt: number): SyncProgressRecord {
    const index: number = LearningPreferences.readingIndex(context);
    let itemId: string = '';
    try {
      const works: ReadingWork[] = ContentRepository.loadReadingWorks(context);
      if (index >= 0 && index < works.length) {
        itemId = works[index].id;
      }
    } catch (error) {
      itemId = '';
    }
    return LearningSyncCoordinator.progressRecord('reading.current', itemId, index, '', updatedAt);
  }

  private static scenarioSeed(context: common.Context, updatedAt: number): SyncProgressRecord {
    const index: number = LearningPreferences.scenarioIndex(context);
    let itemId: string = '';
    try {
      const catalog: LearningCatalog = ContentRepository.loadCatalog(context);
      if (index >= 0 && index < catalog.practiceScenarios.length) {
        itemId = catalog.practiceScenarios[index].id;
      }
    } catch (error) {
      itemId = '';
    }
    return LearningSyncCoordinator.progressRecord('scenario.current', itemId, index, '', updatedAt);
  }

  private static conversationSeeds(context: common.Context, updatedAt: number): SyncConversationSeed[] {
    const stored: StoredConversationSnapshot[] = VocabularyLearningStore.loadAllConversations(context);
    const seeds: SyncConversationSeed[] = [];
    for (let index: number = 0; index < stored.length; index++) {
      const topicType: string = LearningSyncCoordinator.topicType(stored[index].conversationKey);
      const topicId: string = LearningSyncCoordinator.topicId(stored[index].conversationKey, topicType);
      const conversation: SyncConversationRecord = {
        recordId: `${DEFAULT_COURSE_SCOPE.courseId}:conversation:${topicType}:${topicId}`,
        courseId: DEFAULT_COURSE_SCOPE.courseId,
        targetLocale: DEFAULT_COURSE_SCOPE.targetLocale,
        supportLocale: DEFAULT_COURSE_SCOPE.supportLocale,
        topicType: topicType,
        topicId: topicId,
        updatedAt: updatedAt,
        deleted: false
      };
      seeds.push({
        conversation: conversation,
        messages: LearningSyncCoordinator.normalizedMessages(stored[index].messages)
      });
    }
    return seeds;
  }

  private static async applySnapshot(context: common.Context, snapshot: LearningSyncSnapshot): Promise<void> {
    await LearningSyncCoordinator.applyProgress(context, snapshot.progress);
    LearningSyncCoordinator.applyLearnedItems(context, snapshot.learnedItems);
    LearningSyncCoordinator.applyConversations(context, snapshot.conversations);
  }

  private static async applyProgress(context: common.Context, records: SyncProgressRecord[]): Promise<void> {
    const journeyStage: SyncProgressRecord | undefined = LearningSyncCoordinator.latest(records, 'journey.stage');
    const journeyCompleted: SyncProgressRecord | undefined =
      LearningSyncCoordinator.latest(records, 'journey.completed');
    if (journeyStage !== undefined || journeyCompleted !== undefined) {
      const journeyId: string = journeyStage !== undefined ? journeyStage.itemId :
        (journeyCompleted !== undefined ? journeyCompleted.itemId : LearningPreferences.journeyId(context));
      const stage: number = journeyStage === undefined ? LearningPreferences.journeyStage(context) :
        journeyStage.numericValue;
      const remoteMask: number = journeyCompleted === undefined ? 0 : journeyCompleted.numericValue;
      const completedMask: number = LearningPreferences.journeyCompletedMask(context) | remoteMask;
      LearningPreferences.saveJourneyProgress(context, journeyId, stage, completedMask);
      if (journeyCompleted !== undefined && completedMask !== remoteMask) {
        await LearningSyncStore.upsertProgressNow(context,
          LearningSyncCoordinator.progressRecord('journey.completed', journeyId, completedMask, ''));
      }
    }

    const kana: SyncProgressRecord | undefined = LearningSyncCoordinator.latest(records, 'kana.current');
    if (kana !== undefined && kana.itemId.length > 0) {
      LearningPreferences.saveKanaKey(context, kana.itemId);
    }

    const grammar: SyncProgressRecord | undefined = LearningSyncCoordinator.latest(records, 'grammar.current');
    if (grammar !== undefined) {
      const entries: GrammarIndexEntry[] = ContentRepository.loadGrammarIndex(context);
      LearningPreferences.saveGrammarIndex(context,
        LearningSyncCoordinator.indexForGrammar(grammar, entries));
    }

    const music: SyncProgressRecord | undefined = LearningSyncCoordinator.latest(records, 'music.current');
    if (music !== undefined) {
      const tracks: MusicTrack[] = ContentRepository.loadMusicTracks(context);
      LearningPreferences.saveMusicIndex(context,
        LearningSyncCoordinator.indexForMusic(music, tracks));
    }

    LearningSyncCoordinator.applyMusicPositions(context, records);

    const reading: SyncProgressRecord | undefined = LearningSyncCoordinator.latest(records, 'reading.current');
    if (reading !== undefined) {
      const works: ReadingWork[] = ContentRepository.loadReadingWorks(context);
      LearningPreferences.saveReadingIndex(context,
        LearningSyncCoordinator.indexForReading(reading, works));
    }

    const scenario: SyncProgressRecord | undefined = LearningSyncCoordinator.latest(records, 'scenario.current');
    if (scenario !== undefined) {
      const catalog: LearningCatalog = ContentRepository.loadCatalog(context);
      LearningPreferences.saveScenarioIndex(context,
        LearningSyncCoordinator.indexForScenario(scenario, catalog.practiceScenarios));
    }
  }

  private static applyLearnedItems(context: common.Context, records: SyncLearnedItemRecord[]): void {
    const wordsById: Map<string, VocabularyEntry> = new Map<string, VocabularyEntry>();
    for (let levelIndex: number = 0; levelIndex < VOCABULARY_LEVELS.length; levelIndex++) {
      const words: VocabularyEntry[] = ContentRepository.loadVocabulary(context, VOCABULARY_LEVELS[levelIndex]);
      for (let wordIndex: number = 0; wordIndex < words.length; wordIndex++) {
        wordsById.set(words[wordIndex].id, words[wordIndex]);
      }
    }
    const snapshots: LearnedVocabularySnapshot[] = [];
    for (let index: number = 0; index < records.length; index++) {
      const record: SyncLearnedItemRecord = records[index];
      if (record.courseId !== DEFAULT_COURSE_SCOPE.courseId ||
        record.targetLocale !== DEFAULT_COURSE_SCOPE.targetLocale || record.deleted) {
        continue;
      }
      const word: VocabularyEntry | undefined = wordsById.get(record.itemId);
      if (word !== undefined) {
        snapshots.push(VocabularyLearningStore.snapshot(word));
      }
    }
    if (!VocabularyLearningStore.saveLearnedWords(context, snapshots, false, DEFAULT_COURSE_SCOPE)) {
      throw new Error('local-learned-items-write-failed');
    }
  }

  private static applyConversations(context: common.Context, records: SyncConversationSeed[]): void {
    for (let index: number = 0; index < records.length; index++) {
      const seed: SyncConversationSeed = records[index];
      const conversation: SyncConversationRecord = seed.conversation;
      if (conversation.courseId !== DEFAULT_COURSE_SCOPE.courseId ||
        conversation.targetLocale !== DEFAULT_COURSE_SCOPE.targetLocale || conversation.deleted) {
        continue;
      }
      const saved: boolean = VocabularyLearningStore.saveConversation(
        context,
        VocabularyLearningStore.conversationKey(conversation.topicType, conversation.topicId),
        seed.messages,
        conversation.targetLocale,
        conversation.supportLocale,
        conversation.courseId,
        false
      );
      if (!saved) {
        throw new Error('local-conversation-write-failed');
      }
    }
  }

  private static latest(records: SyncProgressRecord[], kind: string): SyncProgressRecord | undefined {
    let result: SyncProgressRecord | undefined = undefined;
    for (let index: number = 0; index < records.length; index++) {
      const record: SyncProgressRecord = records[index];
      if (record.courseId === DEFAULT_COURSE_SCOPE.courseId &&
        record.targetLocale === DEFAULT_COURSE_SCOPE.targetLocale && record.kind === kind && !record.deleted &&
        (result === undefined || record.updatedAt > result.updatedAt)) {
        result = record;
      }
    }
    return result;
  }

  private static applyMusicPositions(context: common.Context, records: SyncProgressRecord[]): void {
    const latestByTrack: Map<string, SyncProgressRecord> = new Map<string, SyncProgressRecord>();
    for (let index: number = 0; index < records.length; index++) {
      const record: SyncProgressRecord = records[index];
      if (record.courseId !== DEFAULT_COURSE_SCOPE.courseId ||
        record.targetLocale !== DEFAULT_COURSE_SCOPE.targetLocale || record.kind !== 'music.position' ||
        record.deleted || record.itemId.length === 0) {
        continue;
      }
      const previous: SyncProgressRecord | undefined = latestByTrack.get(record.itemId);
      if (previous === undefined || record.updatedAt > previous.updatedAt) {
        latestByTrack.set(record.itemId, record);
      }
    }
    latestByTrack.forEach((record: SyncProgressRecord, trackId: string) => {
      LearningPreferences.saveMusicPosition(context, trackId, record.numericValue);
    });
  }

  private static indexForGrammar(record: SyncProgressRecord, entries: GrammarIndexEntry[]): number {
    for (let index: number = 0; index < entries.length; index++) {
      if (entries[index].id === record.itemId) {
        return index;
      }
    }
    return LearningSyncCoordinator.fallbackIndex(record.numericValue, entries.length);
  }

  private static indexForMusic(record: SyncProgressRecord, entries: MusicTrack[]): number {
    for (let index: number = 0; index < entries.length; index++) {
      if (entries[index].id === record.itemId) {
        return index;
      }
    }
    return LearningSyncCoordinator.fallbackIndex(record.numericValue, entries.length);
  }

  private static indexForReading(record: SyncProgressRecord, entries: ReadingWork[]): number {
    for (let index: number = 0; index < entries.length; index++) {
      if (entries[index].id === record.itemId) {
        return index;
      }
    }
    return LearningSyncCoordinator.fallbackIndex(record.numericValue, entries.length);
  }

  private static indexForScenario(record: SyncProgressRecord, entries: PracticeScenario[]): number {
    for (let index: number = 0; index < entries.length; index++) {
      if (entries[index].id === record.itemId) {
        return index;
      }
    }
    return LearningSyncCoordinator.fallbackIndex(record.numericValue, entries.length);
  }

  private static fallbackIndex(index: number, count: number): number {
    if (index < 0) {
      return -1;
    }
    return count > 0 ? Math.max(0, Math.min(index, count - 1)) : -1;
  }

  private static progressRecord(kind: string, itemId: string, numericValue: number,
    textValue: string, updatedAt: number = Date.now()): SyncProgressRecord {
    return {
      recordId: `${DEFAULT_COURSE_SCOPE.courseId}:progress:${kind}`,
      courseId: DEFAULT_COURSE_SCOPE.courseId,
      targetLocale: DEFAULT_COURSE_SCOPE.targetLocale,
      supportLocale: DEFAULT_COURSE_SCOPE.supportLocale,
      kind: kind,
      itemId: itemId,
      numericValue: numericValue,
      textValue: textValue,
      updatedAt: updatedAt,
      deleted: false
    };
  }

  private static musicPositionRecord(trackId: string, positionMs: number,
    updatedAt: number = Date.now()): SyncProgressRecord {
    return {
      recordId: `${DEFAULT_COURSE_SCOPE.courseId}:progress:music.position:${trackId}`,
      courseId: DEFAULT_COURSE_SCOPE.courseId,
      targetLocale: DEFAULT_COURSE_SCOPE.targetLocale,
      supportLocale: DEFAULT_COURSE_SCOPE.supportLocale,
      kind: 'music.position',
      itemId: trackId,
      numericValue: Math.max(0, Math.floor(positionMs)),
      textValue: '',
      updatedAt: updatedAt,
      deleted: false
    };
  }

  private static normalizedMessages(messages: PracticeMessage[]): PracticeMessage[] {
    const result: PracticeMessage[] = [];
    for (let index: number = 0; index < messages.length; index++) {
      const message: PracticeMessage = messages[index];
      result.push({
        id: message.id,
        role: message.role,
        text: message.text,
        revision: message.revision,
        languageTag: message.languageTag === undefined ? 'und' : message.languageTag,
        createdAt: message.createdAt === undefined ?
          LearningSyncCoordinator.timestampFromId(message.id) : message.createdAt
      });
    }
    return result;
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

  private static topicType(conversationKey: string): string {
    const separator: number = conversationKey.indexOf('-');
    return separator > 0 ? conversationKey.slice(0, separator) : 'content';
  }

  private static topicId(conversationKey: string, topicType: string): string {
    const prefix: string = `${topicType}-`;
    return conversationKey.startsWith(prefix) ? conversationKey.slice(prefix.length) : conversationKey;
  }

  private static errorCode(error: Object): string {
    const businessError: BusinessError = error as BusinessError;
    if (businessError.code !== undefined) {
      return businessError.code.toString();
    }
    const standardError: Error = error as Error;
    return standardError.message === undefined ? 'unknown' : standardError.message;
  }

  private static needsConfiguration(detail: string): boolean {
    return detail === '401' || detail === '801' || detail === '14800000' ||
      detail === 'cloud-sync-progress-3';
  }
}
