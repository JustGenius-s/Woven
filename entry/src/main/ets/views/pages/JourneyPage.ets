import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { MOTION_DURATION } from '../../common/AppTheme';
import {
  Dialogue,
  DialogueLine,
  GrammarIndexEntry,
  JourneyKanaFocus,
  KanaCell,
  KanaRow,
  LearningCatalog,
  LearningJourney,
  VocabularyEntry
} from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { PitchNotation } from '../../services/PitchNotation';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { PitchAccentMark } from '../components/PitchAccentMark';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { contentLightEffect, HdsInteractiveSurface, planeLightEffect } from '../components/ImmersiveCanvas';
import { GravityMark } from '../components/GravityMark';
import { GrammarPage } from './GrammarPage';

const JOURNEY_STAGE_LABELS: string[] = ['入景', '识音', '记词', '懂句', '会话', '开口'];
const JOURNEY_STAGE_INDEXES: number[] = [0, 1, 2, 3, 4, 5];
const ANSWER_LABELS: string[] = ['A', 'B', 'C', 'D'];
const EMPTY_JOURNEY: LearningJourney = {
  id: '',
  order: 0,
  title: '',
  japaneseTitle: '',
  setting: '',
  level: '入门',
  duration: '',
  goal: '',
  opening: '',
  kana: [],
  vocabularyLevel: 'N5',
  wordIds: [],
  grammarLessonId: '',
  grammarPattern: '',
  grammarMeaning: '',
  grammarExamples: [],
  dialogueId: '',
  practice: {
    id: '',
    title: '',
    setting: '',
    learnerRole: '',
    aiRole: '',
    level: '入门',
    goal: '',
    openingHint: ''
  },
  challenge: {
    prompt: '',
    options: [],
    answerIndex: 0,
    explanation: ''
  }
};

@Component
export struct JourneyPage {
  journey: LearningJourney = EMPTY_JOURNEY;
  initialStage: number = 0;
  initialCompletedMask: number = 0;
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};
  onBack: () => void = () => {};
  onProgress: (journeyId: string, stage: number, completedMask: number) => void =
    (journeyId: string, stage: number, completedMask: number) => {};

  @State private stageIndex: number = 0;
  @State private completedMask: number = 0;
  @State private catalog: LearningCatalog | undefined = undefined;
  @State private dialogue: Dialogue | undefined = undefined;
  @State private kanaCells: KanaCell[] = [];
  @State private words: VocabularyEntry[] = [];
  @State private grammarEntries: GrammarIndexEntry[] = [];
  @State private selectedKanaIndex: number = 0;
  @State private selectedWordIndex: number = 0;
  @State private showDialogueNotes: boolean = false;
  @State private selectedAnswerIndex: number = -1;
  @State private showFullGrammar: boolean = false;
  @State private loadError: string = '';
  private stageScrollers: Scroller[] = [
    new Scroller(), new Scroller(), new Scroller(),
    new Scroller(), new Scroller(), new Scroller()
  ];

  aboutToAppear(): void {
    this.stageIndex = Math.max(0, Math.min(this.initialStage, JOURNEY_STAGE_LABELS.length - 1));
    this.completedMask = this.initialCompletedMask;
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.catalog = ContentRepository.loadCatalog(context);
      this.grammarEntries = ContentRepository.loadGrammarIndex(context);
      this.words = this.selectWords(ContentRepository.loadVocabulary(context, this.journey.vocabularyLevel));
      this.dialogue = this.selectDialogue(this.catalog.dialogues);
      this.kanaCells = this.selectKana(this.catalog);
      this.loadError = '';
    } catch (error) {
      this.loadError = '这条学习旅程没有完整载入';
    }
  }

  private selectWords(source: VocabularyEntry[]): VocabularyEntry[] {
    const selected: VocabularyEntry[] = [];
    for (let refIndex: number = 0; refIndex < this.journey.wordIds.length; refIndex++) {
      for (let index: number = 0; index < source.length; index++) {
        if (source[index].id === this.journey.wordIds[refIndex]) {
          selected.push(source[index]);
          break;
        }
      }
    }
    return selected;
  }

  private selectDialogue(dialogues: Dialogue[]): Dialogue | undefined {
    for (let index: number = 0; index < dialogues.length; index++) {
      if (dialogues[index].id === this.journey.dialogueId) {
        return dialogues[index];
      }
    }
    return undefined;
  }

  private selectKana(catalog: LearningCatalog): KanaCell[] {
    const selected: KanaCell[] = [];
    const groups: KanaRow[][] = [catalog.kanaGroups.basic, catalog.kanaGroups.voiced,
      catalog.kanaGroups.contracted];
    for (let focusIndex: number = 0; focusIndex < this.journey.kana.length; focusIndex++) {
      const focus: JourneyKanaFocus = this.journey.kana[focusIndex];
      for (let groupIndex: number = 0; groupIndex < groups.length; groupIndex++) {
        for (let rowIndex: number = 0; rowIndex < groups[groupIndex].length; rowIndex++) {
          const row: KanaRow = groups[groupIndex][rowIndex];
          for (let cellIndex: number = 0; cellIndex < row.cells.length; cellIndex++) {
            if (row.cells[cellIndex].key === focus.key) {
              selected.push(row.cells[cellIndex]);
            }
          }
        }
      }
    }
    return selected;
  }

  private grammarIndex(): number {
    for (let index: number = 0; index < this.grammarEntries.length; index++) {
      if (this.grammarEntries[index].id === this.journey.grammarLessonId) {
        return index;
      }
    }
    return 0;
  }

  private askSelection(selection: string, source: string, context: string): void {
    this.onAsk(AiInquiryFactory.selection(selection, source, context));
  }

  private askKanaSelection(selection: string, index: number): void {
    if (this.kanaCells.length === 0 || index < 0 || index >= this.kanaCells.length) {
      return;
    }
    const cell: KanaCell = this.kanaCells[index];
    const cue: string = index < this.journey.kana.length ? this.journey.kana[index].cue : '';
    const cueLine: string = cue.length > 0 ? `\n学习提示：${cue}` : '';
    this.askSelection(selection, `${this.journey.title} · 假名`,
      `平假名：${cell.hira}\n片假名：${cell.kata}\n罗马音：${cell.romaji}${cueLine}`);
  }

  private wordContext(index: number): string {
    if (index < 0 || index >= this.words.length) {
      return '';
    }
    const item: VocabularyEntry = this.words[index];
    const pitch: string = PitchNotation.summary(item);
    const pitchLine: string = pitch.length > 0 ? `\n音调：${pitch}` : '';
    const example: string = item.example === undefined ? '' :
      `\n例句：${item.example.japanese}\n例句释义：${item.example.english}`;
    return `单词：${item.word}\n读音：${item.reading}${pitchLine}\n释义：${item.meanings.join('；')}${example}`;
  }

  private askWordSelection(selection: string, index: number): void {
    if (index < 0 || index >= this.words.length) {
      return;
    }
    this.askSelection(selection, `${this.journey.title} · ${this.words[index].word}`, this.wordContext(index));
  }

  private askDialogueSelection(selection: string, line: DialogueLine): void {
    if (this.dialogue === undefined) {
      return;
    }
    const context: string = `场景：${this.dialogue.setting}\n主题：${this.dialogue.title}\n说话人：${line.speaker}\n` +
      `原句：${line.text}\n读音：${line.reading}\n释义：${line.meaning}`;
    this.askSelection(selection, `${this.dialogue.title} · ${line.speaker}`, context);
  }

  private selectKanaForInquiry(index: number): void {
    this.selectedKanaIndex = index;
  }

  private selectWordForInquiry(index: number): void {
    this.selectedWordIndex = index;
  }

  private selectStage(index: number): void {
    const next: number = Math.max(0, Math.min(index, JOURNEY_STAGE_LABELS.length - 1));
    this.stageIndex = next;
    this.onProgress(this.journey.id, next, this.completedMask);
  }

  private completeAndGo(nextStage: number): void {
    const nextMask: number = this.completedMask | (1 << this.stageIndex);
    const next: number = Math.max(0, Math.min(nextStage, JOURNEY_STAGE_LABELS.length - 1));
    this.getUIContext().animateTo({ curve: curves.springMotion(0.38, 0.8, 0.2) }, () => {
      this.completedMask = nextMask;
      this.stageIndex = next;
    });
    this.onProgress(this.journey.id, next, nextMask);
  }

  private completePractice(): void {
    const nextMask: number = this.completedMask | (1 << 5);
    this.getUIContext().animateTo({ curve: curves.springMotion(0.34, 0.84, 0.18) }, () => {
      this.completedMask = nextMask;
    });
    this.onProgress(this.journey.id, 5, nextMask);
  }

  private answer(index: number): void {
    this.getUIContext().animateTo({ curve: curves.responsiveSpringMotion(0.18, 0.86, 0.12) }, () => {
      this.selectedAnswerIndex = index;
    });
    if (index === this.journey.challenge.answerIndex) {
      const nextMask: number = this.completedMask | (1 << 5);
      this.getUIContext().animateTo({ curve: curves.springMotion(0.36, 0.82, 0.18) }, () => {
        this.completedMask = nextMask;
      });
      this.onProgress(this.journey.id, 5, nextMask);
    }
  }

  private completedCount(): number {
    let count: number = 0;
    for (let index: number = 0; index < JOURNEY_STAGE_LABELS.length; index++) {
      if ((this.completedMask & (1 << index)) !== 0) {
        count += 1;
      }
    }
    return count;
  }

  private setFullGrammar(show: boolean): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.4, 0.86, 0.16) }, () => {
      this.showFullGrammar = show;
    });
  }

  build() {
    if (this.showFullGrammar) {
      GrammarPage({
        entries: this.grammarEntries,
        initialIndex: this.grammarIndex(),
        onIndexChange: (index: number) => {},
        onAsk: this.onAsk,
        onBack: () => this.setFullGrammar(false)
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ x: 20 }))
        .animation({ curve: curves.springMotion(0.4, 0.86, 0.16) }))
    } else {
      Column() {
        ImmersiveBackChrome({
          title: this.journey.title,
          subtitle: this.journey.setting,
          onBack: this.onBack,
          scrollers: this.stageScrollers,
          pageContent: () => {
            this.journeyContent()
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.985, y: 0.985 }))
        .animation({ curve: curves.springMotion(0.4, 0.88, 0.14) }))
    }
  }

  @Builder
  private journeyContent() {
    Column() {
      if (this.loadError.length > 0) {
          Column({ space: 12 }) {
            Text('旅程暂时无法展开')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text(this.loadError)
              .fontSize(14)
              .fontColor($r('app.color.danger'))
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          this.masthead()
          this.stageRail()
          Swiper() {
            ForEach(JOURNEY_STAGE_INDEXES, (index: number) => {
              this.stagePage(index)
            })
          }
          .index(this.stageIndex)
          .indicator(false)
          .loop(false)
          .duration(MOTION_DURATION)
          .curve(curves.springMotion(0.42, 0.86, 0.16))
          .layoutWeight(1)
          .onChange((index: number) => this.selectStage(index))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private masthead() {
    Row() {
      Column({ space: 5 }) {
        Text(this.journey.japaneseTitle)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(this.journey.japaneseTitle,
            (selection: string) => this.askSelection(selection, this.journey.title,
              `${this.journey.japaneseTitle}\n${this.journey.goal}`)))
        Text(`${this.journey.level}  ${this.journey.duration}  ·  ${this.completedCount()}/6 已贯通`)
          .fontSize(11)
          .fontColor($r('app.color.ink_muted'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      GravityMark({ diameter: 70, progress: this.stageIndex })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 8, bottom: 12 })
    .visualEffect(contentLightEffect())
  }

  @Builder
  private stageRail() {
    Row({ space: 5 }) {
      ForEach(JOURNEY_STAGE_LABELS, (label: string, index: number) => {
        Text(this.stageIndex === index ? label :
          ((this.completedMask & (1 << index)) !== 0 ? '✓' : (index + 1).toString()))
          .width(this.stageIndex === index ? 66 : 38)
          .height(38)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.stageIndex === index ? Color.White :
            ((this.completedMask & (1 << index)) !== 0 ?
              $r('app.color.accent') : $r('app.color.ink_muted')))
          .textAlign(TextAlign.Center)
          .borderRadius(19)
          .backgroundColor(this.stageIndex === index ?
            $r('app.color.accent') : $r('app.color.surface_raised'))
          .border({ width: 0.5, color: this.stageIndex === index ?
            $r('app.color.accent') : $r('app.color.line') })
          .shadow({ radius: this.stageIndex === index ? 13 : 0,
            color: $r('app.color.gravity_glow'), offsetY: 4 })
          .animation({ curve: curves.springMotion(0.36, 0.8, 0.2) })
          .accessibilityText(`第${index + 1}阶段，${label}`)
        .onClick(() => this.selectStage(index))
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 18, right: 18, bottom: 8 })
  }

  @Builder
  private stagePage(index: number) {
    Scroll(this.stageScrollers[index]) {
      Column({ space: 20 }) {
        if (index === 0) {
          this.sceneStage()
        } else if (index === 1) {
          this.kanaStage()
        } else if (index === 2) {
          this.vocabularyStage()
        } else if (index === 3) {
          this.grammarStage()
        } else if (index === 4) {
          this.dialogueStage()
        } else {
          this.practiceStage()
        }
        Column().height(28)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .clip(false)
  }

  @Builder
  private sceneStage() {
    HdsInteractiveSurface({
      planeStrong: true,
      interactive: true,
      planeContent: () => {
        this.scenePlane()
      }
    })
    if (this.dialogue !== undefined) {
      Column({ space: 14 }) {
        Text('先听懂对方会说什么')
          .width('100%')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        ForEach((this.dialogue?.lines ?? []).slice(0, 2), (line: DialogueLine) => {
          Row({ space: 12 }) {
            Text(line.speaker)
              .width(52)
              .fontSize(10)
              .fontColor($r('app.color.accent'))
            Text(line.text)
              .layoutWeight(1)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
              .lineHeight(28)
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(line.text,
                (selection: string) => this.askDialogueSelection(selection, line)))
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ top: 12, bottom: 12 })
          .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 8, right: 8 })
      .visualEffect(contentLightEffect())
    }
  }

  @Builder
  private scenePlane() {
    Column({ space: 20 }) {
      Row() {
        Text(this.journey.setting)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
          .letterSpacing(1)
        Blank()
        Text('先进入情境')
          .fontSize(11)
          .fontColor($r('app.color.ink_muted'))
      }
      Text(this.journey.opening)
        .width('100%')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .lineHeight(46)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(12)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.journey.opening,
          (selection: string) => this.askSelection(selection, this.journey.title,
            `${this.journey.opening}\n${this.journey.goal}`)))
      Text(this.journey.goal)
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(25)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.journey.goal,
          (selection: string) => this.askSelection(selection, this.journey.title,
            `${this.journey.opening}\n${this.journey.goal}`)))
      Row() {
        Blank()
        ImmersiveAction({
          label: '拆开这句话',
          actionAccessibilityText: '进入关键假名',
          icon: $r('sys.symbol.arrow_right'),
          emphasized: true,
          onAction: () => this.completeAndGo(1)
        })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(24)
  }

  @Builder
  private kanaStage() {
    Column({ space: 8 }) {
      Text('从这句话里认音')
        .width('100%')
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text('假名不再是一张孤立的表。每个音都落回刚才的场景。')
        .width('100%')
        .fontSize(14)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(23)
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 4, right: 4 })

    if (this.kanaCells.length > 0) {
      HdsInteractiveSurface({
        planeStrong: true,
        interactive: true,
        planeContent: () => {
          this.kanaFocusPlane()
        }
      })
      Row({ space: 8 }) {
        ForEach(this.kanaCells, (cell: KanaCell, index: number) => {
          Column({ space: 2 }) {
            Text(cell.hira)
              .fontSize(25)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedKanaIndex === index ? $r('app.color.accent') : $r('app.color.ink'))
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(cell.hira,
                (selection: string) => this.askKanaSelection(selection, index)))
            Text(cell.romaji)
              .fontSize(9)
              .fontColor($r('app.color.ink_muted'))
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(cell.romaji,
                (selection: string) => this.askKanaSelection(selection, index)))
          }
          .layoutWeight(1)
          .height(66)
          .justifyContent(FlexAlign.Center)
          .borderRadius(18)
          .backgroundColor(this.selectedKanaIndex === index ?
            $r('app.color.accent_soft') : $r('app.color.surface_raised'))
          .scale({ x: this.selectedKanaIndex === index ? 1 : 0.94,
            y: this.selectedKanaIndex === index ? 1 : 0.94 })
          .shadow({ radius: this.selectedKanaIndex === index ? 10 : 0,
            color: $r('app.color.gravity_glow'), offsetY: 3 })
          .animation({ curve: curves.responsiveSpringMotion(0.18, 0.84, 0.12) })
          .visualEffect(contentLightEffect())
          .onClick(() => this.selectKanaForInquiry(index))
        })
      }
      .width('100%')
    }
    Row() {
      Blank()
      ImmersiveAction({
        label: '带着声音记词',
        actionAccessibilityText: '进入旅程词汇',
        icon: $r('sys.symbol.arrow_right'),
        emphasized: true,
        onAction: () => this.completeAndGo(2)
      })
    }
    .width('100%')
  }

  @Builder
  private kanaFocusPlane() {
    Row({ space: 18 }) {
      Text(this.kanaCells[Math.min(this.selectedKanaIndex, this.kanaCells.length - 1)].hira)
        .fontSize(76)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(
          this.kanaCells[Math.min(this.selectedKanaIndex, this.kanaCells.length - 1)].hira,
          (selection: string) => this.askKanaSelection(selection,
            Math.min(this.selectedKanaIndex, this.kanaCells.length - 1))))
      Column({ space: 6 }) {
        Text(this.kanaCells[Math.min(this.selectedKanaIndex, this.kanaCells.length - 1)].kata)
          .fontSize(32)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(
            this.kanaCells[Math.min(this.selectedKanaIndex, this.kanaCells.length - 1)].kata,
            (selection: string) => this.askKanaSelection(selection,
              Math.min(this.selectedKanaIndex, this.kanaCells.length - 1))))
        Text(this.kanaCells[Math.min(this.selectedKanaIndex, this.kanaCells.length - 1)].romaji)
          .fontSize(13)
          .fontColor($r('app.color.accent'))
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(
            this.kanaCells[Math.min(this.selectedKanaIndex, this.kanaCells.length - 1)].romaji,
            (selection: string) => this.askKanaSelection(selection,
              Math.min(this.selectedKanaIndex, this.kanaCells.length - 1))))
        Text(this.journey.kana[Math.min(this.selectedKanaIndex, this.journey.kana.length - 1)].cue)
          .fontSize(15)
          .fontColor($r('app.color.ink_muted'))
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(
            this.journey.kana[Math.min(this.selectedKanaIndex, this.journey.kana.length - 1)].cue,
            (selection: string) => this.askKanaSelection(selection,
              Math.min(this.selectedKanaIndex, this.kanaCells.length - 1))))
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
    }
    .width('100%')
    .padding(24)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private vocabularyStage() {
    Column({ space: 8 }) {
      Text('只记马上会用的词')
        .width('100%')
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(`这组 ${this.words.length} 个词，会在后面的句型和会话里再次出现。`)
        .width('100%')
        .fontSize(14)
        .fontColor($r('app.color.ink_muted'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 4, right: 4 })

    Row({ space: 8 }) {
      ForEach(this.words, (word: VocabularyEntry, index: number) => {
        Text(word.word)
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontWeight(this.selectedWordIndex === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selectedWordIndex === index ? $r('app.color.accent') : $r('app.color.ink'))
          .textAlign(TextAlign.Center)
          .borderRadius(15)
          .backgroundColor(this.selectedWordIndex === index ?
            $r('app.color.accent_soft') : $r('app.color.surface_raised'))
          .scale({ x: this.selectedWordIndex === index ? 1 : 0.95,
            y: this.selectedWordIndex === index ? 1 : 0.95 })
          .shadow({ radius: this.selectedWordIndex === index ? 10 : 0,
            color: $r('app.color.gravity_glow'), offsetY: 3 })
          .animation({ curve: curves.responsiveSpringMotion(0.18, 0.84, 0.12) })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(word.word,
            (selection: string) => this.askWordSelection(selection, index)))
          .onClick(() => this.selectWordForInquiry(index))
      })
    }
    .width('100%')

    if (this.words.length > 0) {
      HdsInteractiveSurface({
        planeStrong: true,
        interactive: true,
        planeContent: () => {
          this.wordFocusPlane()
        }
      })
    }
    Row() {
      Blank()
      ImmersiveAction({
        label: '把词放进句子',
        actionAccessibilityText: '进入旅程句型',
        icon: $r('sys.symbol.arrow_right'),
        emphasized: true,
        onAction: () => this.completeAndGo(3)
      })
    }
    .width('100%')
  }

  @Builder
  private wordFocusPlane() {
    Column({ space: 14 }) {
      Row() {
        Text(this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].word)
          .fontSize(44)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(
            this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].word,
            (selection: string) => this.askWordSelection(selection,
              Math.min(this.selectedWordIndex, this.words.length - 1))))
        Blank()
        Text(this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].reading)
          .fontSize(15)
          .fontColor($r('app.color.accent'))
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(
            this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].reading,
            (selection: string) => this.askWordSelection(selection,
              Math.min(this.selectedWordIndex, this.words.length - 1))))
      }
      .width('100%')
      if (this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].pitches !== undefined &&
        this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].pitches.length > 0) {
        PitchAccentMark({
          pitches: this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].pitches
        })
      }
      Text(this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].meanings.slice(0, 2).join('；'))
        .width('100%')
        .fontSize(17)
        .fontColor($r('app.color.ink'))
        .lineHeight(27)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(
          this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].meanings.slice(0, 2).join('；'),
          (selection: string) => this.askWordSelection(selection,
            Math.min(this.selectedWordIndex, this.words.length - 1))))
      if (this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].example !== undefined) {
        Text(this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].example?.japanese ?? '')
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink_muted'))
          .lineHeight(28)
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(
            this.words[Math.min(this.selectedWordIndex, this.words.length - 1)].example?.japanese ?? '',
            (selection: string) => this.askWordSelection(selection,
              Math.min(this.selectedWordIndex, this.words.length - 1))))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(24)
  }

  @Builder
  private grammarStage() {
    HdsInteractiveSurface({
      planeStrong: true,
      planeContent: () => {
        this.grammarFocusPlane()
      }
    })
    Column({ space: 0 }) {
      ForEach(this.journey.grammarExamples, (example: string, index: number) => {
        Row({ space: 14 }) {
          Text((index + 1).toString().padStart(2, '0'))
            .width(26)
            .fontSize(10)
            .fontColor($r('app.color.accent'))
          Text(example)
            .layoutWeight(1)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .lineHeight(28)
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(example,
              (selection: string) => this.askSelection(selection, this.journey.title,
                `${this.journey.grammarPattern}\n${this.journey.grammarMeaning}\n${example}`)))
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 15, bottom: 15 })
        .borderRadius(14)
        .border({ width: { bottom: index + 1 < this.journey.grammarExamples.length ? 0.5 : 0 },
          color: $r('app.color.line') })
      })
    }
    .width('100%')
    .padding({ left: 8, right: 8 })
    .visualEffect(contentLightEffect())
    Row() {
      ImmersiveAction({
        label: '完整语法课',
        actionAccessibilityText: '打开完整语法课',
        icon: $r('sys.symbol.bookmark'),
        onAction: () => this.setFullGrammar(true)
      })
      Blank()
      ImmersiveAction({
        label: '进入会话',
        actionAccessibilityText: '进入完整会话',
        icon: $r('sys.symbol.arrow_right'),
        emphasized: true,
        onAction: () => this.completeAndGo(4)
      })
    }
    .width('100%')
  }

  @Builder
  private grammarFocusPlane() {
    Column({ space: 16 }) {
      Text('这次只抓一个句型')
        .width('100%')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
      Text(this.journey.grammarPattern)
        .width('100%')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .lineHeight(48)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(12)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.journey.grammarPattern,
          (selection: string) => this.askSelection(selection, this.journey.title,
            `${this.journey.grammarPattern}\n${this.journey.grammarMeaning}`)))
      Text(this.journey.grammarMeaning)
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(25)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.journey.grammarMeaning,
          (selection: string) => this.askSelection(selection, this.journey.title,
            `${this.journey.grammarPattern}\n${this.journey.grammarMeaning}`)))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(24)
  }

  @Builder
  private dialogueStage() {
    Row() {
      Column({ space: 5 }) {
        Text('把句型放回现场')
          .fontSize(25)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.dialogue?.goal ?? this.journey.goal)
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(this.dialogue?.goal ?? this.journey.goal,
            (selection: string) => this.askSelection(selection, this.journey.title,
              this.dialogue?.goal ?? this.journey.goal)))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button(this.showDialogueNotes ? '收起提示' : '显示读音', {
        type: ButtonType.ROUNDED_RECTANGLE,
        stateEffect: true
      })
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .controlSize(ControlSize.SMALL)
        .onClick(() => this.showDialogueNotes = !this.showDialogueNotes)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 4, right: 4 })

    Column({ space: 0 }) {
      ForEach(this.dialogue?.lines ?? [], (line: DialogueLine, index: number) => {
        Row() {
          if (line.learner === true) {
            Blank()
          }
          Column({ space: 6 }) {
            Text(line.speaker)
              .fontSize(10)
              .fontColor(line.learner === true ? $r('app.color.accent') : $r('app.color.ink_muted'))
            Text(line.text)
              .width('100%')
              .fontSize(line.learner === true ? 19 : 22)
              .fontWeight(line.learner === true ? FontWeight.Medium : FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .lineHeight(line.learner === true ? 29 : 33)
              .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(line.text,
                (selection: string) => this.askDialogueSelection(selection, line)))
            if (this.showDialogueNotes) {
              Text(line.reading)
                .width('100%')
                .fontSize(12)
                .fontColor($r('app.color.ink_muted'))
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(line.reading,
                  (selection: string) => this.askDialogueSelection(selection, line)))
              Text(line.meaning)
                .width('100%')
                .fontSize(12)
                .fontColor($r('app.color.ink_muted'))
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(line.meaning,
                  (selection: string) => this.askDialogueSelection(selection, line)))
            }
          }
          .width(line.learner === true ? '82%' : '90%')
          .alignItems(line.learner === true ? HorizontalAlign.End : HorizontalAlign.Start)
          if (line.learner !== true) {
            Blank()
          }
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 16, bottom: 16 })
        .borderRadius(14)
        .border({ width: { bottom: index + 1 < (this.dialogue?.lines.length ?? 0) ? 0.5 : 0 },
          color: $r('app.color.line') })
      })
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
    .borderRadius(26)
    .backgroundColor($r('app.color.surface_raised'))
    .visualEffect(planeLightEffect())
    Row() {
      Blank()
      ImmersiveAction({
        label: '轮到你开口',
        actionAccessibilityText: '进入开口练习',
        icon: $r('sys.symbol.arrow_right'),
        emphasized: true,
        onAction: () => this.completeAndGo(5)
      })
    }
    .width('100%')
  }

  @Builder
  private practiceStage() {
    Column({ space: 8 }) {
      Text('先做一次情境判断')
        .width('100%')
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(this.journey.challenge.prompt)
        .width('100%')
        .fontSize(16)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(26)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.journey.challenge.prompt,
          (selection: string) => this.askSelection(selection, `${this.journey.title} · 情境判断`,
            `${this.journey.challenge.prompt}\n${this.journey.challenge.explanation}`)))
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 4, right: 4 })

    Column({ space: 10 }) {
      ForEach(this.journey.challenge.options, (option: string, index: number) => {
        Row({ space: 12 }) {
          Text(ANSWER_LABELS[index] ?? (index + 1).toString())
            .width(28)
            .height(28)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.selectedAnswerIndex === index ? $r('app.color.accent') : $r('app.color.ink_muted'))
            .textAlign(TextAlign.Center)
            .borderRadius(14)
            .backgroundColor($r('app.color.accent_soft'))
          Text(option)
            .layoutWeight(1)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .lineHeight(25)
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(option,
              (selection: string) => this.askSelection(selection, `${this.journey.title} · 情境判断`,
                `${this.journey.challenge.prompt}\n${option}\n${this.journey.challenge.explanation}`)))
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 15, bottom: 15 })
        .borderRadius(20)
        .backgroundColor(this.selectedAnswerIndex === index ?
          $r('app.color.accent_soft') : $r('app.color.surface_raised'))
        .border({
          width: this.selectedAnswerIndex === index ? 1 : 0.5,
          color: this.selectedAnswerIndex === index ? $r('app.color.accent') : $r('app.color.line')
        })
        .scale({
          x: this.selectedAnswerIndex < 0 || this.selectedAnswerIndex === index ? 1 : 0.98,
          y: this.selectedAnswerIndex < 0 || this.selectedAnswerIndex === index ? 1 : 0.98
        })
        .opacity(this.selectedAnswerIndex < 0 || this.selectedAnswerIndex === index ? 1 : 0.72)
        .animation({ curve: curves.responsiveSpringMotion(0.18, 0.84, 0.12) })
        .visualEffect(contentLightEffect())
        .onClick(() => this.answer(index))
      })
    }
    .width('100%')

    if (this.selectedAnswerIndex >= 0) {
      Column({ space: 7 }) {
        Text(this.selectedAnswerIndex === this.journey.challenge.answerIndex ? '判断正确' : '再看一下句型关系')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.selectedAnswerIndex === this.journey.challenge.answerIndex ?
            $r('app.color.success') : $r('app.color.danger'))
        Text(this.journey.challenge.explanation)
          .fontSize(14)
          .fontColor($r('app.color.ink_muted'))
          .lineHeight(23)
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(this.journey.challenge.explanation,
            (selection: string) => this.askSelection(selection, `${this.journey.title} · 情境判断`,
              `${this.journey.challenge.prompt}\n${this.journey.challenge.explanation}`)))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .border({ width: { left: 3 }, color: $r('app.color.accent') })
      .visualEffect(contentLightEffect())
    }

    HdsInteractiveSurface({
      planeStrong: true,
      interactive: true,
      planeContent: () => {
        this.practiceLaunchPlane()
      }
    })
  }

  @Builder
  private practiceLaunchPlane() {
    Column({ space: 14 }) {
      Row({ space: 16 }) {
        Column({ space: 6 }) {
          Text('离线开口任务')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(`${this.journey.practice.learnerRole}  ×  ${this.journey.practice.aiRole}`)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        ImmersiveAction({
          label: (this.completedMask & (1 << 5)) !== 0 ? '已完成' : '标记完成',
          actionAccessibilityText: `完成${this.journey.practice.title}开口任务`,
          icon: $r('sys.symbol.paperplane_fill'),
          emphasized: true,
          onAction: () => this.completePractice()
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.journey.practice.openingHint)
        .width('100%')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink'))
        .lineHeight(28)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(this.journey.practice.openingHint,
          (selection: string) => this.askSelection(selection, this.journey.practice.title,
            `${this.journey.practice.setting}\n${this.journey.practice.goal}\n` +
              this.journey.practice.openingHint)))
      Text('不依赖网络：先遮住提示说一遍，再打开核对表达。')
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(20)
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}
