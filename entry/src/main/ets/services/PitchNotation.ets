import { VocabularyEntry, WordPitch } from '../model/ContentModels';

export class PitchNotation {
  static primary(item: VocabularyEntry): WordPitch | undefined {
    if (item.pitches === undefined || item.pitches.length === 0) {
      return undefined;
    }
    return item.pitches[0];
  }

  static isHigh(pattern: WordPitch, moraIndex: number): boolean {
    if (pattern.accent <= 0) {
      return moraIndex > 0;
    }
    if (pattern.accent === 1) {
      return moraIndex === 0;
    }
    return moraIndex > 0 && moraIndex < pattern.accent;
  }

  static summary(item: VocabularyEntry): string {
    const pattern: WordPitch | undefined = PitchNotation.primary(item);
    if (pattern === undefined) {
      return '';
    }
    return `${pattern.accent}`;
  }
}
