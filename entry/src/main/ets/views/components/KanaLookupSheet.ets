import { common } from '@kit.AbilityKit';
import { KanaCell, KanaGroups, KanaRow, LearningCatalog } from '../../model/ContentModels';
import { ContentRepository } from '../../services/ContentRepository';
import { KanaAudioService } from '../../services/KanaAudioService';
import { matchKanaKeys } from '../../services/KanaLookupService';

/**
 * The kana chart in a sheet, highlighting every kana that occurs in the text the
 * user selected.
 *
 * The chart is read from the repository on demand so the sheet owns everything it
 * needs and the caller only supplies the query.
 */
@Component
export struct KanaLookupSheet {
  // Re-match on every new query: the sheet stays mounted between lookups, so
  // aboutToAppear alone would leave the previous highlight in place.
  @Prop @Watch('onQueryChange') query: string = '';
  @State private catalog: LearningCatalog | undefined = undefined;
  @State private loadError: string = '';
  @State private matchedKeys: string[] = [];

  aboutToAppear(): void {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      KanaAudioService.initialize(context);
      this.catalog = ContentRepository.loadCatalog(context);
      this.loadError = '';
      this.refreshMatches();
    } catch (error) {
      this.loadError = '假名资源没有正确载入';
    }
  }

  onQueryChange(): void {
    this.refreshMatches();
  }

  private refreshMatches(): void {
    if (this.catalog === undefined) {
      this.matchedKeys = [];
      return;
    }
    this.matchedKeys = matchKanaKeys(this.query, this.catalog.kanaGroups);
  }

  private highlighted(key: string): boolean {
    return this.matchedKeys.indexOf(key) >= 0;
  }

  build() {
    Column() {
      if (this.loadError.length > 0) {
        Text(this.loadError)
          .fontSize(14)
          .fontColor($r('app.color.danger'))
          .padding(24)
      } else if (this.catalog === undefined) {
        LoadingProgress()
          .width(28)
          .height(28)
          .margin(24)
      } else {
        this.summary()
        Scroll() {
          Column() {
            this.group('清音', this.catalog.kanaGroups.basic)
            this.group('濁音・半濁音', this.catalog.kanaGroups.voiced)
            this.group('拗音', this.catalog.kanaGroups.contracted)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 28 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  private summary() {
    Row({ space: 8 }) {
      Text(`选中：${this.query}`)
        .fontSize(13)
        .fontColor($r('app.color.ink_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.matchedKeys.length > 0 ? `匹配 ${this.matchedKeys.length} 个` : '未匹配到假名')
        .fontSize(12)
        .fontColor(this.matchedKeys.length > 0 ? $r('app.color.accent') : $r('app.color.ink_muted'))
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 6, bottom: 10 })
  }

  @Builder
  private group(title: string, rows: KanaRow[]) {
    Column({ space: 0 }) {
      Text(title)
        .width('100%')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
        .letterSpacing(1)
        .padding({ left: 8, top: 20, bottom: 10 })
      ForEach(rows, (row: KanaRow) => {
        Column({ space: 4 }) {
          Text(row.label)
            .width('100%')
            .fontSize(10)
            .fontColor($r('app.color.ink_muted'))
            .padding({ left: 6 })
          Row({ space: 2 }) {
            ForEach(row.cells, (cell: KanaCell) => {
              Column({ space: 2 }) {
                Text(cell.hira)
                  .width('100%')
                  .fontSize(cell.hira.length > 1 ? 19 : 24)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ink'))
                  .maxLines(1)
                  .textAlign(TextAlign.Center)
                Text(cell.kata)
                  .width('100%')
                  .fontSize(cell.kata.length > 1 ? 13 : 15)
                  .fontColor($r('app.color.ink_muted'))
                  .maxLines(1)
                  .textAlign(TextAlign.Center)
                Text(cell.romaji)
                  .width('100%')
                  .fontSize(cell.romaji.length > 4 ? 8 : 9)
                  .fontColor($r('app.color.accent'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .height(78)
              .justifyContent(FlexAlign.Center)
              .onClick(() => KanaAudioService.play(cell.romaji))
              // Matched kana get the accent plate; the rest stay neutral.
              .backgroundColor(this.highlighted(cell.key) ?
                $r('app.color.accent_soft') : Color.Transparent)
              .borderRadius(14)
              .border(this.highlighted(cell.key) ?
                { width: 1, color: $r('app.color.accent') } : { width: 0, color: Color.Transparent })
            }, (cell: KanaCell) => cell.key)
            if (row.cells.length < 5) {
              ForEach(new Array<number>(5 - row.cells.length).fill(0), (item: number) => {
                Blank().layoutWeight(1)
              })
            }
          }
          .width('100%')
        }
        .width('100%')
        .padding({ top: 5, bottom: 5 })
        .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
      }, (row: KanaRow) => row.label)
    }
    .width('100%')
  }
}
