import { common } from '@kit.AbilityKit';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { JourneyKanaFocus, KanaCell, KanaRow, LearningCatalog, LearningJourney } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { AiAskAction } from '../components/AiAskAction';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

@Component
export struct KanaPage {
  journey: LearningJourney | undefined = undefined;
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};

  @State private catalog: LearningCatalog | undefined = undefined;
  @State private selected: KanaCell | undefined = undefined;
  @State private selectionActive: boolean = false;
  @State private loadError: string = '';

  aboutToAppear(): void {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.catalog = ContentRepository.loadCatalog(context);
      if (this.catalog.kanaGroups.basic.length > 0 && this.catalog.kanaGroups.basic[0].cells.length > 0) {
        this.selected = this.catalog.kanaGroups.basic[0].cells[0];
      }
      if (this.journey !== undefined && this.journey.kana.length > 0) {
        const journeyCell: KanaCell | undefined = this.findKana(this.journey.kana[0].key);
        if (journeyCell !== undefined) {
          this.selected = journeyCell;
        }
      }
      this.selectionActive = false;
      this.loadError = '';
    } catch (error) {
      this.loadError = '假名资源没有正确载入';
    }
  }

  build() {
    Column() {
      PageChrome({ title: '五十音' })
      if (this.journey !== undefined && this.catalog !== undefined) {
        this.journeyBridge()
      }
      if (this.loadError.length > 0) {
        Text(this.loadError)
          .layoutWeight(1)
          .fontSize(16)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
      } else if (this.catalog !== undefined) {
        List({ space: 0 }) {
          ListItem() {
            this.group('清音', this.catalog?.kanaGroups.basic ?? [])
          }
          ListItem() {
            this.group('濁音・半濁音', this.catalog?.kanaGroups.voiced ?? [])
          }
          ListItem() {
            this.group('拗音', this.catalog?.kanaGroups.contracted ?? [])
          }

          ListItem() {
            Row({ space: 22 }) {
              Text(this.selected?.hira ?? 'あ')
                .fontSize(64)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
              Column({ space: 7 }) {
                Text(this.selected?.kata ?? 'ア')
                  .fontSize(31)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ink'))
                Text(this.selected?.romaji ?? 'a')
                  .fontSize(14)
                  .fontColor($r('app.color.accent'))
                  .letterSpacing(1)
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              if (this.selected !== undefined && this.selectionActive) {
                AiAskAction({
                  label: '问这个音',
                  onAsk: () => this.askSelectedKana()
                })
              }
            }
            .width('100%')
            .padding({ top: 40, bottom: 38, left: 12 })
            .alignItems(VerticalAlign.Center)
            .borderRadius(30)
            .clip(true)
            .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
            .border({ width: 0.5, color: $r('app.color.immersive_edge') })
            .visualEffect(planeLightEffect())
          }

          ListItem() {
            Column({ space: 26 }) {
              this.note('01', '先认形，再联音', '不要把平假名和片假名拆成两套背。看到一个音时，同时说出两种写法。')
              this.note('02', '拗音是一拍', 'きゃ、しゅ、ちょ 等组合不是两个独立音节，小写的 ゃ・ゅ・ょ 要和前一个假名连读。')
              this.note('03', '每天只练一组', '按行朗读，再用真实词复习，比机械抄写整张表更容易形成声音记忆。')
            }
            .width('100%')
            .padding({ top: 36, bottom: FLOATING_TAB_CONTENT_INSET })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 14, right: 14 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  private findKana(key: string): KanaCell | undefined {
    if (this.catalog === undefined) {
      return undefined;
    }
    const groups: KanaRow[][] = [this.catalog.kanaGroups.basic, this.catalog.kanaGroups.voiced,
      this.catalog.kanaGroups.contracted];
    for (let groupIndex: number = 0; groupIndex < groups.length; groupIndex++) {
      for (let rowIndex: number = 0; rowIndex < groups[groupIndex].length; rowIndex++) {
        const row: KanaRow = groups[groupIndex][rowIndex];
        for (let cellIndex: number = 0; cellIndex < row.cells.length; cellIndex++) {
          if (row.cells[cellIndex].key === key) {
            return row.cells[cellIndex];
          }
        }
      }
    }
    return undefined;
  }

  private askSelectedKana(): void {
    if (this.selected === undefined) {
      return;
    }
    let cue: string = '';
    const focuses: JourneyKanaFocus[] = this.journey?.kana ?? [];
    for (let index: number = 0; index < focuses.length; index++) {
      if (focuses[index].key === this.selected.key) {
        cue = focuses[index].cue;
        break;
      }
    }
    this.onAsk(AiInquiryFactory.kana(this.selected, cue));
  }

  private selectKana(cell: KanaCell): void {
    if (this.selected?.key === cell.key && this.selectionActive) {
      this.selectionActive = false;
      return;
    }
    this.selected = cell;
    this.selectionActive = true;
  }

  @Builder
  private journeyBridge() {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text('当前旅程')
          .fontSize(10)
          .fontColor($r('app.color.accent'))
        Text(this.journey?.title ?? '')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
      }
      .width(82)
      .alignItems(HorizontalAlign.Start)
      ForEach(this.journey?.kana ?? [], (focus: JourneyKanaFocus) => {
        Column({ space: 2 }) {
          Text(focus.key)
            .fontSize(20)
            .fontWeight(this.selected?.key === focus.key ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.selected?.key === focus.key ? $r('app.color.accent') : $r('app.color.ink'))
          Text(focus.cue)
            .fontSize(8)
            .fontColor($r('app.color.ink_muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .borderRadius(14)
        .backgroundColor(this.selected?.key === focus.key ?
          $r('app.color.accent_soft') : Color.Transparent)
        .onClick(() => {
          const cell: KanaCell | undefined = this.findKana(focus.key);
          if (cell !== undefined) {
            this.selectKana(cell);
          }
        })
      })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 6, bottom: 10 })
    .visualEffect(contentLightEffect())
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
        .padding({ left: 8, top: 24, bottom: 12 })
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
                  .fontSize(cell.hira.length > 1 ? 20 : 26)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ink'))
                  .maxLines(1)
                  .textAlign(TextAlign.Center)
                Text(cell.kata)
                  .width('100%')
                  .fontSize(cell.kata.length > 1 ? 14 : 16)
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
              .height(86)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.selected?.key === cell.key ?
                $r('app.color.immersive_plane_strong') : Color.Transparent)
              .borderRadius(14)
              .visualEffect(contentLightEffect())
              .onClick(() => this.selectKana(cell))
            }, (cell: KanaCell) => cell.key)
            if (row.cells.length < 5) {
              ForEach(new Array<number>(5 - row.cells.length).fill(0), (item: number, index: number) => {
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
    .padding({ left: 8, right: 8, bottom: 10 })
    .margin({ top: 10, bottom: 8 })
    .borderRadius(28)
    .clip(true)
    .backgroundEffect({ radius: 28, color: $r('app.color.immersive_plane'), saturation: 1.06 })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
  }

  @Builder
  private note(index: string, title: string, body: string) {
    Row({ space: 16 }) {
      Text(index)
        .fontSize(23)
        .fontWeight(FontWeight.Lighter)
        .fontColor($r('app.color.accent'))
        .opacity(0.65)
        .alignSelf(ItemAlign.Start)
      Column({ space: 7 }) {
        Text(title)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(body)
          .fontSize(15)
          .lineHeight(25)
          .fontColor($r('app.color.ink_muted'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .visualEffect(contentLightEffect())
  }
}
