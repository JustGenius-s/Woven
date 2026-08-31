import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { FLOATING_TAB_CONTENT_INSET, MOTION_DURATION } from '../../common/AppTheme';
import {
  GrammarBlock,
  GrammarDocument,
  GrammarIndexEntry,
  GrammarLesson,
  GrammarVocabularyEntry,
  InlineSegment
} from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { GrammarParser } from '../../services/GrammarParser';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';

const EMPTY_GRAMMAR_ENTRY: GrammarIndexEntry = {
  id: '',
  level: 'N5',
  order: 0,
  title: '',
  summary: '',
  sectionCount: 0
};
const EMPTY_GRAMMAR_BLOCK: GrammarBlock = {
  kind: 'paragraph',
  text: '',
  cells: []
};

@Component
export struct GrammarPage {
  entries: GrammarIndexEntry[] = [];
  initialIndex: number = 0;
  onIndexChange: (index: number) => void = (index: number) => {};
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};
  onBack: () => void = () => {};

  @State private lessonIndex: number = 0;

  aboutToAppear(): void {
    this.lessonIndex = Math.max(0, Math.min(this.initialIndex, this.entries.length - 1));
  }

  private jumpLevel(level: string): void {
    for (let index: number = 0; index < this.entries.length; index++) {
      if (this.entries[index].level === level) {
        this.lessonIndex = index;
        this.onIndexChange(index);
        return;
      }
    }
  }

  private nextLesson(): void {
    if (this.lessonIndex + 1 < this.entries.length) {
      this.lessonIndex += 1;
      this.onIndexChange(this.lessonIndex);
    }
  }

  build() {
    Column() {
      ImmersiveBackChrome({ title: '语法', onBack: this.onBack })
      Row({ space: 4 }) {
        ForEach(['N5', 'N4', 'N3', 'N2'], (level: string) => {
          Button(level, {
            type: ButtonType.ROUNDED_RECTANGLE,
            stateEffect: true
          })
            .layoutWeight(1)
            .buttonStyle(this.entries[this.lessonIndex]?.level === level ?
              ButtonStyleMode.NORMAL : ButtonStyleMode.TEXTUAL)
            .controlSize(ControlSize.SMALL)
            .accessibilityText(`${level} 语法`)
            .onClick(() => this.jumpLevel(level))
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
      .visualEffect(contentLightEffect())

      Swiper() {
        ForEach(this.entries, (entry: GrammarIndexEntry, index: number) => {
          GrammarLessonPage({
            entry: entry,
            onAsk: this.onAsk,
            onNext: () => {
              if (index === this.lessonIndex) {
                this.nextLesson();
              }
            }
          })
        }, (entry: GrammarIndexEntry) => entry.id)
      }
      .index(this.lessonIndex)
      .indicator(false)
      .loop(false)
      .duration(MOTION_DURATION)
      .curve(curves.springMotion(0.42, 0.86, 0.16))
      .layoutWeight(1)
      .onChange((index: number) => {
        this.lessonIndex = index;
        this.onIndexChange(index);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

@Component
struct GrammarLessonPage {
  entry: GrammarIndexEntry = EMPTY_GRAMMAR_ENTRY;
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};
  onNext: () => void = () => {};

  @State private lesson: GrammarLesson | undefined = undefined;
  @State private document: GrammarDocument | undefined = undefined;
  @State private loadError: string = '';
  @State private reachedEnd: boolean = false;

  aboutToAppear(): void {
    if (this.lesson !== undefined) {
      return;
    }
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.lesson = ContentRepository.loadGrammarLesson(context, this.entry.id);
      this.document = GrammarParser.parse(this.lesson.content);
      this.loadError = '';
    } catch (error) {
      this.loadError = '这一课没有正确载入';
    }
  }

  private askLessonSelection(selection: string): void {
    this.onAsk(AiInquiryFactory.selection(selection, this.entry.title,
      `${this.entry.title}\n${this.entry.summary}`));
  }

  build() {
    if (this.loadError.length > 0) {
      Column({ space: 12 }) {
        Text(this.loadError)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(28)
    } else if (this.lesson !== undefined && this.document !== undefined) {
      List({ space: 0 }) {
        ListItem() {
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Text(this.entry.level)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent'))
                .letterSpacing(1.4)
              Text(`第 ${this.entry.order} 课`)
                .fontSize(11)
                .fontColor($r('app.color.ink_muted'))
            }
            .width('100%')

            Text(this.entry.title)
              .width('100%')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .lineHeight(40)
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(this.entry.title,
                (selection: string) => this.askLessonSelection(selection)))
            Text(this.entry.summary)
              .width('100%')
              .fontSize(15)
              .fontColor($r('app.color.ink_muted'))
              .lineHeight(24)
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(this.entry.summary,
                (selection: string) => this.askLessonSelection(selection)))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 20, bottom: 22 })
          .margin({ top: 12, bottom: 16 })
          .borderRadius(24)
          .clip(true)
          .backgroundEffect({ radius: 28, color: $r('app.color.immersive_plane_strong'), saturation: 1.06 })
          .border({ width: 0.5, color: $r('app.color.immersive_edge') })
          .visualEffect(planeLightEffect())
        }
        .width('100%')

        ForEach(this.document?.blocks ?? [], (block: GrammarBlock, index: number) => {
          ListItem() {
            Column() {
              GrammarBlockView({
                block: block,
                vocabulary: this.document?.vocabulary ?? [],
                source: this.entry.title,
                onAsk: this.onAsk
              })
            }
            .width('100%')
          }
          .width('100%')
        }, (block: GrammarBlock, index: number) => `${this.entry.id}-${index}`)

        ListItem() {
          Column()
            .height(FLOATING_TAB_CONTENT_INSET)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => this.reachedEnd = true)
      .parallelGesture(
        PanGesture({ direction: PanDirection.Vertical, distance: 12 })
          .onActionEnd((event: GestureEvent) => {
            if (this.reachedEnd && event.offsetY < -72) {
              this.reachedEnd = false;
              this.onNext();
            }
          })
      )
    } else {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('app.color.accent'))
        Text('正在展开课程')
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }
}

@Component
struct GrammarBlockView {
  block: GrammarBlock = EMPTY_GRAMMAR_BLOCK;
  vocabulary: GrammarVocabularyEntry[] = [];
  source: string = '';
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};
  @State private selectedWord: string = '';
  @State private selectedReading: string = '';
  @State private selectedMeaning: string = '';

  private select(segment: InlineSegment): void {
    if (!segment.annotated) {
      return;
    }
    if (this.selectedWord === segment.word) {
      this.selectedWord = '';
      return;
    }
    this.selectedWord = segment.word;
    this.selectedReading = segment.reading;
    this.selectedMeaning = segment.meaning;
  }

  private contextText(): string {
    if (this.block.kind !== 'table') {
      return this.block.text;
    }
    const rows: string[] = [];
    for (let index: number = 0; index < this.block.cells.length; index++) {
      rows.push(this.block.cells[index].join(' | '));
    }
    return rows.join('\n');
  }

  private askSelection(selection: string): void {
    this.onAsk(AiInquiryFactory.selection(selection, this.source, this.contextText()));
  }

  build() {
    if (this.block.kind === 'heading') {
      Column({ space: 8 }) {
        Text(this.block.text)
          .width('100%')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .lineHeight(36)
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(this.block.text,
            (selection: string) => this.askSelection(selection)))
        Divider()
          .width(36)
          .strokeWidth(2)
          .color($r('app.color.accent'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 28, bottom: 12 })
    } else if (this.block.kind === 'subheading') {
      Text(this.block.text)
        .width('100%')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .lineHeight(28)
        .padding({ left: 20, right: 20, top: 18, bottom: 8 })
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.block.text,
          (selection: string) => this.askSelection(selection)))
    } else if (this.block.kind === 'table') {
      Column() {
        ForEach(this.block.cells, (row: string[], rowIndex: number) => {
          Row() {
            ForEach(row, (cell: string) => {
              Text(cell)
                .layoutWeight(1)
                .fontSize(rowIndex === 0 ? 13 : 14)
                .fontWeight(rowIndex === 0 ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(rowIndex === 0 ? $r('app.color.ink_muted') : $r('app.color.ink'))
                .lineHeight(21)
                .padding({ left: 7, right: 7, top: 10, bottom: 10 })
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(cell,
                  (selection: string) => this.askSelection(selection)))
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .backgroundColor(rowIndex === 0 ? $r('app.color.accent_soft') : Color.Transparent)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
        })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 10 })
      .margin({ top: 6, bottom: 16 })
      .borderRadius(18)
      .clip(true)
      .backgroundEffect({ radius: 22, color: $r('app.color.immersive_plane'), saturation: 1.04 })
      .border({ width: 0.5, color: $r('app.color.immersive_edge') })
      .visualEffect(planeLightEffect())
    } else if (this.block.kind === 'list') {
      Column({ space: 4 }) {
        ForEach(this.block.text.split('\n'), (item: string, index: number) => {
          Row({ space: 8 }) {
            Text(this.block.ordered === true ? `${index + 1}.` : '•')
              .width(24)
              .fontSize(this.block.ordered === true ? 12 : 17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent'))
              .textAlign(TextAlign.Center)
            Text(item)
              .layoutWeight(1)
              .fontSize(16)
              .fontColor($r('app.color.ink'))
              .lineHeight(27)
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(item,
                (selection: string) => this.askSelection(selection)))
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: 4, right: 4, top: 8, bottom: 8 })
          .borderRadius(12)
        })
      }
      .width('100%')
      .padding({ left: 2, right: 2, top: 4, bottom: 12 })
      .alignItems(HorizontalAlign.Start)
    } else if (this.block.kind === 'note') {
      Text(this.block.text)
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(25)
        .padding({ left: 16, right: 15, top: 15, bottom: 15 })
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.block.text,
          (selection: string) => this.askSelection(selection)))
      .margin({ top: 8, bottom: 8 })
      .borderRadius(16)
      .border({ width: { left: 3 }, color: $r('app.color.accent') })
      .backgroundEffect({ radius: 22, color: $r('app.color.immersive_plane'), saturation: 1.04 })
      .visualEffect(planeLightEffect())
    } else {
      Column({ space: 9 }) {
        Text() {
          ForEach(GrammarParser.annotate(this.block.text, this.vocabulary), (segment: InlineSegment,
            index: number) => {
            Span(segment.text)
              .fontColor(segment.annotated ? $r('app.color.accent') : $r('app.color.ink'))
              .fontWeight(segment.annotated ? FontWeight.Medium : FontWeight.Regular)
              .backgroundColor(segment.annotated && this.selectedWord === segment.word ?
                $r('app.color.accent_soft') : Color.Transparent)
              .onClick(() => this.select(segment))
          }, (segment: InlineSegment, index: number) => `${index}-${segment.text}`)
        }
        .width('100%')
        .fontSize(17)
        .fontColor($r('app.color.ink'))
        .lineHeight(29)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.block.text,
          (selection: string) => this.askSelection(selection)))

        if (this.selectedWord.length > 0) {
          Column({ space: 6 }) {
            Row({ space: 8 }) {
              Text(this.selectedWord)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.accent'))
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(this.selectedWord,
                  (selection: string) => this.askSelection(selection)))
              Text(this.selectedReading)
                .fontSize(13)
                .fontColor($r('app.color.ink_muted'))
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(this.selectedReading,
                  (selection: string) => this.askSelection(selection)))
            }
            .width('100%')
            Text(this.selectedMeaning)
              .width('100%')
              .fontSize(13)
              .fontColor($r('app.color.ink'))
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(this.selectedMeaning,
                (selection: string) => this.askSelection(selection)))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 14, right: 4, top: 8, bottom: 8 })
          .border({ width: { left: 2 }, color: $r('app.color.accent') })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 6, bottom: 10 })
      .borderRadius(12)
    }
  }
}
