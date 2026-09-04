export interface GrammarAudioTrack {
  id: string;
  title: string;
  key: string;
  bytes: number;
  durationMs: number;
}

export interface GrammarWork {
  id: string;
  level: string;
  cefr: string;
  lessonNo: number;
  title: string;
  titleJa: string;
  topic: string;
  summary: string;
  sourceName: string;
  sourceUrl: string;
  rights: string;
  coverKey?: string;
  coverBytes?: number;
  coverRatio?: number;
  pdfKey: string;
  pdfBytes?: number;
  pageCount: number;
  workbookKey?: string;
  workbookBytes?: number;
  answerKey?: string;
  answerBytes?: number;
  audioTracks: GrammarAudioTrack[];
  audioBytes?: number;
  sortOrder: number;
}
