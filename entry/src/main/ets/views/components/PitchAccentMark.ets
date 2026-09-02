import { WordPitch } from '../../model/ContentModels';
import { PitchNotation } from '../../services/PitchNotation';

@Component
export struct PitchAccentMark {
  pitches: WordPitch[] = [];
  asReading: boolean = false;

  private pattern(): WordPitch | undefined {
    if (this.pitches === undefined || this.pitches.length === 0) {
      return undefined;
    }
    return this.pitches[0];
  }

  build() {
    if (this.pattern() === undefined) {
      Column()
    } else {
      Row({ space: this.asReading ? 1 : 4 }) {
        ForEach(this.pattern()?.morae ?? [], (mora: string, index: number) => {
          this.moraColumn(mora, index)
        }, (mora: string, index: number) => `${index}-${mora}`)
      }
      .alignItems(VerticalAlign.Bottom)
      .accessibilityText(`音调 ${this.pattern()?.accent ?? ''}`)
    }
  }

  @Builder
  private moraColumn(mora: string, index: number) {
    Column({ space: this.asReading ? 2 : 4 }) {
      Column()
        .width(this.asReading ? 14 : 16)
        .height(2)
        .borderRadius(1)
        .backgroundColor($r('app.color.accent'))
        .opacity(PitchNotation.isHigh(this.pattern() as WordPitch, index) ? 1 : 0.22)
      Text(mora)
        .fontSize(15)
        .fontColor(this.asReading ? $r('app.color.ink_muted') : $r('app.color.ink'))
    }
    .alignItems(HorizontalAlign.Center)
  }
}
