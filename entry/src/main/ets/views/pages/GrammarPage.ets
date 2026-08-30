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
import { ResponseInputMessage, ResponsesCreateRequest } from '../../model/AiModels';
import { ContentRepository } from '../../services/ContentRepository';
import { GrammarParser } from '../../services/GrammarParser';
import { ResponsesClient } from '../../services/ResponsesClient';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';
import { InlineAiResult } from '../components/PageChrome';

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
  gatewayUrl: string = '';
  appToken: string = '';
  model: string = '';
  onIndexChange: (index: number) => void = (index: number) => {};
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
      Row({ space: 22 }) {
        ForEach(['N5', 'N4', 'N3', 'N2'], (level: string) => {
          Text(level)
            .fontSize(13)
            .fontWeight(this.entries[this.lessonIndex]?.level === level ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.entries[this.lessonIndex]?.level === level ?
              $r('app.color.accent') : $r('app.color.ink_muted'))
            .onClick(() => this.jumpLevel(level))
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 12 })
      .visualEffect(contentLightEffect())

      Swiper() {
        ForEach(this.entries, (entry: GrammarIndexEntry, index: number) => {
          GrammarLessonPage({
            entry: entry,
            gatewayUrl: this.gatewayUrl,
            appToken: this.appToken,
            model: this.model,
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
  gatewayUrl: string = '';
  appToken: string = '';
  model: string = '';
  onNext: () => void = () => {};

  @State private lesson: GrammarLesson | undefined = undefined;
  @State private document: GrammarDocument | undefined = undefined;
  @State private loadError: string = '';
  @State private aiText: string = '';
  @State private aiLoading: boolean = false;
  @State private aiError: string = '';
  @State private reachedEnd: boolean = false;
  private aiClient?: ResponsesClient;

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

  aboutToDisappear(): void {
    this.aiClient?.cancel();
  }

  private askAi(): void {
    if (this.lesson === undefined || this.aiLoading) {
      return;
    }
    this.aiClient = new ResponsesClient(this.gatewayUrl, this.appToken);
    this.aiText = '';
    this.aiError = '';
    this.aiLoading = true;
    const input: ResponseInputMessage[] = [{
      role: 'user',
      content: [{
        type: 'input_text',
        text: `请基于下面课程，提炼三个真正需要记住的判断，并给一个自然日语微型对话。不要复述目录。\n\n${this.lesson.content.slice(0, 14000)}`
      }]
    }];
    const body: ResponsesCreateRequest = {
      model: this.model,
      instructions: '你是严谨的日语教师。用简洁中文讲解，日语例句保留日文并标出必要读音。不编造课文中没有的规则。输出纯文本。',
      input: input,
      stream: true,
      store: false
    };
    this.aiClient.stream(body, {
      onDelta: (delta: string) => this.aiText += delta,
      onCompleted: (responseId: string) => this.aiLoading = false,
      onError: (message: string) => {
        this.aiLoading = false;
        this.aiError = message;
      }
    }).catch(() => {
      this.aiLoading = false;
    });
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
          Row({ space: 18 }) {
            Text(this.entry.order.toString().padStart(2, '0'))
              .fontSize(48)
              .fontWeight(FontWeight.Lighter)
              .fontColor($r('app.color.accent'))
              .opacity(0.64)
              .alignSelf(ItemAlign.Start)
            Column({ space: 12 }) {
              Text(this.entry.level)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent'))
                .letterSpacing(1.4)
              Text(this.entry.title)
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .lineHeight(45)
              Text(this.entry.summary)
                .fontSize(15)
                .fontColor($r('app.color.ink_muted'))
                .lineHeight(25)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: 22, right: 22, top: 24, bottom: 28 })
          .margin({ top: 16, bottom: 26 })
          .borderRadius(30)
          .clip(true)
          .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
          .border({ width: 0.5, color: $r('app.color.immersive_edge') })
          .visualEffect(planeLightEffect())
        }

        ForEach(this.document?.blocks ?? [], (block: GrammarBlock, index: number) => {
          ListItem() {
            GrammarBlockView({ block: block, vocabulary: this.document?.vocabulary ?? [] })
          }
        }, (block: GrammarBlock, index: number) => `${this.entry.id}-${index}`)

        ListItem() {
          Column({ space: 16 }) {
            InlineAiResult({ title: '本课提炼', text: this.aiText, loading: this.aiLoading, error: this.aiError })
            if (!this.aiLoading && this.aiText.length === 0) {
              ImmersiveAction({
                label: 'AI 讲解',
                actionAccessibilityText: '生成本课 AI 讲解',
                icon: $r('sys.symbol.dot_radiowaves_left_and_right'),
                emphasized: true,
                onAction: () => this.askAi()
              })
            }
            Column()
              .height(34)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 10, bottom: FLOATING_TAB_CONTENT_INSET })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 26, right: 26 })
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

  build() {
    if (this.block.kind === 'heading') {
      Row({ space: 13 }) {
        Text('文法')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.accent'))
          .letterSpacing(1)
          .rotate({ angle: -90 })
          .width(28)
        Text(this.block.text)
          .layoutWeight(1)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .lineHeight(38)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: 38, bottom: 17 })
      .visualEffect(contentLightEffect())
    } else if (this.block.kind === 'subheading') {
      Text(this.block.text)
        .width('94%')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .lineHeight(29)
        .padding({ left: 18, top: 22, bottom: 10 })
        .alignSelf(ItemAlign.End)
        .visualEffect(contentLightEffect())
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
            })
          }
          .width('100%')
          .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
        })
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 10, bottom: 12 })
      .margin({ top: 8, bottom: 18 })
      .borderRadius(22)
      .clip(true)
      .backgroundEffect({ radius: 24, color: $r('app.color.immersive_plane'), saturation: 1.04 })
      .border({ width: 0.5, color: $r('app.color.immersive_edge') })
      .visualEffect(planeLightEffect())
    } else if (this.block.kind === 'list') {
      Column({ space: 10 }) {
        ForEach(this.block.text.split('\n'), (item: string, index: number) => {
          Row({ space: 13 }) {
            Text((index + 1).toString().padStart(2, '0'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent'))
            Text(item)
              .layoutWeight(1)
              .fontSize(16)
              .fontColor($r('app.color.ink'))
              .lineHeight(27)
          }
          .alignItems(VerticalAlign.Top)
        })
      }
      .width('100%')
      .padding({ top: 5, bottom: 13 })
      .alignItems(HorizontalAlign.Start)
      .visualEffect(contentLightEffect())
    } else if (this.block.kind === 'note') {
      Row({ space: 14 }) {
        Divider()
          .vertical(true)
          .width(3)
          .height('100%')
          .color($r('app.color.accent'))
        Text(this.block.text)
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.ink_muted'))
          .lineHeight(25)
      }
      .width('100%')
      .padding({ left: 16, right: 15, top: 15, bottom: 15 })
      .margin({ top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
      .borderRadius(20)
      .backgroundEffect({ radius: 22, color: $r('app.color.immersive_plane'), saturation: 1.04 })
      .visualEffect(planeLightEffect())
    } else {
      Column({ space: 9 }) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          ForEach(GrammarParser.annotate(this.block.text, this.vocabulary), (segment: InlineSegment,
            index: number) => {
            Text(segment.text)
              .fontSize(17)
              .fontColor(segment.annotated ? $r('app.color.accent') : $r('app.color.ink'))
              .fontWeight(segment.annotated ? FontWeight.Medium : FontWeight.Regular)
              .lineHeight(29)
              .backgroundColor(Color.Transparent)
              .onHover((isHover: boolean) => {
                if (isHover && segment.annotated && this.selectedWord !== segment.word) {
                  this.select(segment);
                }
              })
              .onClick(() => this.select(segment))
          }, (segment: InlineSegment, index: number) => `${index}-${segment.text}`)
        }
        .width('100%')

        if (this.selectedWord.length > 0) {
          Row({ space: 8 }) {
            Text(this.selectedWord)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent'))
            Text(this.selectedReading)
              .fontSize(13)
              .fontColor($r('app.color.ink_muted'))
            Text(this.selectedMeaning)
              .layoutWeight(1)
              .fontSize(13)
              .fontColor($r('app.color.ink'))
          }
          .width('100%')
          .padding({ left: 14, top: 8, bottom: 8 })
          .border({ width: { left: 2 }, color: $r('app.color.accent') })
          .visualEffect(contentLightEffect())
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 5, bottom: 8 })
      .visualEffect(contentLightEffect())
    }
  }
}
