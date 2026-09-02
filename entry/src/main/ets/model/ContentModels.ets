export enum AppSection {
  LEARN = 0,
  KANA = 1,
  VOCABULARY = 2,
  EXPLORE = 3,
  ME = 4
}

export interface KanaCell {
  key: string;
  hira: string;
  kata: string;
  romaji: string;
}

export interface KanaRow {
  label: string;
  cells: KanaCell[];
}

export interface KanaGroups {
  basic: KanaRow[];
  voiced: KanaRow[];
  contracted: KanaRow[];
}

export interface DialogueLine {
  speaker: string;
  text: string;
  reading: string;
  meaning: string;
  learner?: boolean;
}

export interface Dialogue {
  id: string;
  title: string;
  setting: string;
  level: string;
  goal: string;
  lines: DialogueLine[];
}

export interface PracticeScenario {
  id: string;
  title: string;
  setting: string;
  learnerRole: string;
  aiRole: string;
  level: string;
  goal: string;
  openingHint: string;
}

export interface MusicLine {
  text: string;
  reading: string;
  meaning: string;
  startMs: number;
}

export interface MusicTrack {
  id: string;
  title: string;
  chineseTitle: string;
  artist: string;
  level: string;
  focus: string;
  audioSource: string;
  artworkName: string;
  durationMs: number;
  lines: MusicLine[];
}

export interface ReadingPassage {
  title?: string;
  text: string;
  note: string;
}

export interface ReadingWork {
  id: string;
  title: string;
  titleReading: string;
  author: string;
  level: string;
  genre: string;
  summary: string;
  sourceName: string;
  sourceUrl: string;
  rights: string;
  complete?: boolean;
  passages: ReadingPassage[];
}

export interface JourneyKanaFocus {
  key: string;
  cue: string;
}

export interface JourneyChallenge {
  prompt: string;
  options: string[];
  answerIndex: number;
  explanation: string;
}

export interface LearningJourney {
  id: string;
  order: number;
  title: string;
  japaneseTitle: string;
  setting: string;
  level: string;
  duration: string;
  goal: string;
  opening: string;
  kana: JourneyKanaFocus[];
  vocabularyLevel: string;
  wordIds: string[];
  grammarLessonId: string;
  grammarPattern: string;
  grammarMeaning: string;
  grammarExamples: string[];
  dialogueId: string;
  practice: PracticeScenario;
  challenge: JourneyChallenge;
}

export interface LearningCatalog {
  schemaVersion: number;
  kanaGroups: KanaGroups;
  dialogues: Dialogue[];
  practiceScenarios: PracticeScenario[];
}

export interface ContentManifestVocabulary {
  total: number;
  extraTotal?: number;
  lexiconTotal?: number;
  pitchCoverage?: number;
  extraPitchCoverage?: number;
}

export interface ContentManifestGrammar {
  totalLessons: number;
  totalSections: number;
}

export interface ContentManifest {
  vocabulary: ContentManifestVocabulary;
  grammar: ContentManifestGrammar;
}

export interface GrammarIndexEntry {
  id: string;
  level: string;
  order: number;
  title: string;
  summary: string;
  sectionCount: number;
}

export interface GrammarLesson {
  id: string;
  level: string;
  order: number;
  title: string;
  summary: string;
  sectionCount: number;
  content: string;
}

export interface GrammarVocabularyEntry {
  word: string;
  reading: string;
  meaning: string;
}

export interface GrammarBlock {
  kind: string;
  text: string;
  cells: string[][];
  ordered?: boolean;
}

export interface GrammarDocument {
  blocks: GrammarBlock[];
  vocabulary: GrammarVocabularyEntry[];
}

export interface InlineSegment {
  text: string;
  word: string;
  reading: string;
  meaning: string;
  annotated: boolean;
}

export interface VocabularyExample {
  japanese: string;
  english: string;
}

/**
 * Tokyo-style pitch drop. `accent` is the NHK/Wadoku nucleus:
 * 0 heiban, 1 atamadaka, 2..n-1 nakadaka, n odaka.
 */
export interface WordPitch {
  accent: number;
  morae: string[];
  source: string;
}

export interface VocabularyEntry {
  id: string;
  level: string;
  word: string;
  reading: string;
  meanings: string[];
  common: boolean;
  pitches: WordPitch[];
  example?: VocabularyExample;
}
