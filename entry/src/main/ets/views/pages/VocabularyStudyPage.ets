import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { MOTION_DURATION } from '../../common/AppTheme';
import { GrammarIndexEntry, LearningJourney, VocabularyEntry } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { VocabularyDataSource } from '../../services/VocabularyDataSource';
import {
  LearnedVocabularySnapshot,
  VocabularyLearningStore
} from '../../services/VocabularyLearningStore';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { planeLightEffect } from '../components/ImmersiveCanvas';

const JOURNEY_WORD_STAGE_MASK: number = 1 << 2;
const JOURNEY_GRAMMAR_STAGE_MASK: number = 1 << 3;
const RECENT_GRAMMAR_LIMIT: number = 6;
const RECENT_WORD_LIMIT: number = 16;

@Component
export struct VocabularyStudyPage {
  level: string = 'N5';
  wordIds: string[] = [];
  initialWordId: string = '';
  journey: LearningJourney | undefined = undefined;
  learnedGrammarIndex: number = 0;
  journeyCompletedMask: number = 0;
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};
  onBack: () => void = () => {};
  onToneChange: (toneIndex: number) => void = (toneIndex: number) => {};

  @State private resultCount: number = 0;
  @State private currentWordIndex: number = 0;
  @State private loadError: string = '';
  @State private learnedWords: LearnedVocabularySnapshot[] = [];
  @State private grammarEntries: GrammarIndexEntry[] = [];
  @State private conversationCount: number = 0;
  @State private pageWidth: number = 360;
  @State private pageHeight: number = 720;
  private dataSource: VocabularyDataSource = new VocabularyDataSource();
  private learnedWordIds: Set<string> = new Set<string>();

  aboutToAppear(): void {
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    this.learnedWords = VocabularyLearningStore.loadLearnedWords(context);
    this.rebuildLearnedIndex(this.learnedWords);
    try {
      this.grammarEntries = ContentRepository.loadGrammarIndex(context);
    } catch (error) {
      this.grammarEntries = [];
    }
    this.loadWords();
  }

  aboutToDisappear(): void {
    this.onToneChange(-1);
  }

  private loadWords(): void {
    try {
      const allWords: VocabularyEntry[] = ContentRepository.loadVocabulary(
        this.getUIContext().getHostContext() as common.Context, this.level);
      const allowedIds: Set<string> = new Set<string>(this.wordIds);
      const words: VocabularyEntry[] = [];
      for (let index: number = 0; index < allWords.length; index++) {
        if (allowedIds.size === 0 || allowedIds.has(allWords[index].id)) {
          words.push(allWords[index]);
        }
      }
      this.syncJourneyWords(allWords);
      this.resultCount = words.length;
      this.currentWordIndex = this.initialIndex(words);
      this.dataSource.reset(words);
      this.loadError = '';
      if (words.length > 0) {
        this.updateActiveWord(words[this.currentWordIndex]);
      } else {
        this.conversationCount = 0;
        this.onToneChange(-1);
      }
    } catch (error) {
      this.resultCount = 0;
      this.currentWordIndex = 0;
      this.conversationCount = 0;
      this.dataSource.reset([]);
      this.loadError = `${this.level} 词库没有正确载入`;
      this.onToneChange(-1);
    }
  }

  private initialIndex(words: VocabularyEntry[]): number {
    for (let index: number = 0; index < words.length; index++) {
      if (words[index].id === this.initialWordId) {
        return index;
      }
    }
    return 0;
  }

  private updateCurrentWord(index: number): void {
    if (index < 0 || index >= this.dataSource.totalCount()) {
      return;
    }
    this.currentWordIndex = index;
    this.updateActiveWord(this.dataSource.getData(index));
  }

  private updateActiveWord(item: VocabularyEntry): void {
    this.conversationCount = VocabularyLearningStore.conversationCount(
      this.getUIContext().getHostContext() as common.Context, this.conversationKey(item));
    this.onToneChange(this.wordToneIndex(item));
  }

  private containsLearnedWord(id: string): boolean {
    return this.learnedWordIds.has(id);
  }

  private rebuildLearnedIndex(words: LearnedVocabularySnapshot[]): void {
    this.learnedWordIds.clear();
    for (let index: number = 0; index < words.length; index++) {
      this.learnedWordIds.add(words[index].id);
    }
  }

  private toggleLearned(item: VocabularyEntry): void {
    const shouldLearn: boolean = !this.containsLearnedWord(item.id);
    const next: LearnedVocabularySnapshot[] = [];
    for (let index: number = 0; index < this.learnedWords.length; index++) {
      if (this.learnedWords[index].id !== item.id) {
        next.push(this.learnedWords[index]);
      }
    }
    if (shouldLearn) {
      next.push(VocabularyLearningStore.snapshot(item));
    }
    this.learnedWords = next;
    this.rebuildLearnedIndex(next);
    VocabularyLearningStore.saveLearnedWords(
      this.getUIContext().getHostContext() as common.Context, next);
    this.dataSource.refresh(item.id);
  }

  private syncJourneyWords(allWords: VocabularyEntry[]): void {
    if (this.journey === undefined || (this.journeyCompletedMask & JOURNEY_WORD_STAGE_MASK) === 0) {
      return;
    }
    const next: LearnedVocabularySnapshot[] = this.learnedWords.slice();
    let changed: boolean = false;
    for (let index: number = 0; index < allWords.length; index++) {
      const item: VocabularyEntry = allWords[index];
      if (!this.journey.wordIds.includes(item.id) || this.containsLearnedWord(item.id)) {
        continue;
      }
      next.push(VocabularyLearningStore.snapshot(item));
      changed = true;
    }
    if (changed) {
      this.learnedWords = next;
      this.rebuildLearnedIndex(next);
      VocabularyLearningStore.saveLearnedWords(
        this.getUIContext().getHostContext() as common.Context, next);
    }
  }

  private learnedGrammarCount(): number {
    if (this.grammarEntries.length === 0) {
      return 0;
    }
    return Math.min(this.grammarEntries.length, Math.max(0, this.learnedGrammarIndex + 1));
  }

  private learningContext(item: VocabularyEntry): string {
    const grammarEnd: number = this.learnedGrammarCount();
    const grammarStart: number = Math.max(0, grammarEnd - RECENT_GRAMMAR_LIMIT);
    let result: string = `目标词：${item.word}（${item.reading}）\n`;
    if (grammarEnd > 0) {
      result += '最近学习的语法：\n';
      for (let index: number = grammarStart; index < grammarEnd; index++) {
        const entry: GrammarIndexEntry = this.grammarEntries[index];
        result += `- ${entry.title}：${entry.summary}\n`;
      }
    } else {
      result += '最近学习的语法：暂无记录\n';
    }

    const wordStart: number = Math.max(0, this.learnedWords.length - RECENT_WORD_LIMIT);
    if (this.learnedWords.length > 0) {
      result += '最近标记学会的单词：\n';
      for (let index: number = wordStart; index < this.learnedWords.length; index++) {
        const word: LearnedVocabularySnapshot = this.learnedWords[index];
        result += `- ${word.word}（${word.reading}）：${word.meaning}\n`;
      }
    } else {
      result += '最近标记学会的单词：暂无记录\n';
    }

    if (this.journey !== undefined && (this.journeyCompletedMask & JOURNEY_GRAMMAR_STAGE_MASK) !== 0) {
      result += `已完成旅程语法：${this.journey.grammarPattern}，${this.journey.grammarMeaning}\n`;
    }
    result += '造句时优先复用这些内容，必要的基础助词和功能词可以正常使用。';
    return result;
  }

  private personalizedPrompt(item: VocabularyEntry): string {
    return `请用「${item.word}」造一个自然、适合我当前进度的日语句子。` +
      '优先使用我已经学过的语法和单词，给出中文翻译，并简短说明复用了哪些已学内容。';
  }

  private conversationKey(item: VocabularyEntry): string {
    return `word-${item.id}`;
  }

  private openWordChat(item: VocabularyEntry, initialPrompt: string = ''): void {
    this.onAsk(AiInquiryFactory.word(item, this.learningContext(item), initialPrompt));
  }

  private askSelection(selection: string, item: VocabularyEntry): void {
    this.openWordChat(item, `请结合单词「${item.word}」解释我选中的内容：「${selection}」。`);
  }

  private wordToneIndex(item: VocabularyEntry): number {
    let hash: number = 0;
    for (let index: number = 0; index < item.id.length; index++) {
      hash = (hash * 31 + item.id.charCodeAt(index)) & 0x7fffffff;
    }
    return hash % 6;
  }

  private wordTone(item: VocabularyEntry): ResourceColor {
    switch (this.wordToneIndex(item)) {
      case 0:
        return $r('app.color.word_card_blue');
      case 1:
        return $r('app.color.word_card_cyan');
      case 2:
        return $r('app.color.word_card_green');
      case 3:
        return $r('app.color.word_card_amber');
      case 4:
        return $r('app.color.word_card_rose');
      default:
        return $r('app.color.word_card_violet');
    }
  }

  private watermark(item: VocabularyEntry): string {
    return item.word.length > 2 ? item.word.slice(0, 2) : item.word;
  }

  private wordFontSize(item: VocabularyEntry): number {
    if (item.word.length > 10) {
      return 28;
    }
    if (item.word.length > 6) {
      return 36;
    }
    return 46;
  }

  private artworkSize(): number {
    if (this.useHorizontalLayout()) {
      const horizontalWidth: number = Math.max(220, (this.pageWidth - 76) * 0.48);
      const horizontalHeight: number = Math.max(220, this.pageHeight - 104);
      return Math.min(horizontalWidth, horizontalHeight, 420);
    }
    const widthLimit: number = Math.min(Math.max(220, this.pageWidth - 48), 420);
    const heightLimit: number = Math.max(220, this.pageHeight * 0.43);
    return Math.min(widthLimit, heightLimit);
  }

  private useHorizontalLayout(): boolean {
    return this.pageWidth >= 700 && this.pageWidth > this.pageHeight;
  }

  private updatePageSize(width: Length, height: Length): void {
    const nextWidth: number = typeof width === 'number' ? width : Number.parseFloat(width as string);
    const nextHeight: number = typeof height === 'number' ? height : Number.parseFloat(height as string);
    if (!Number.isNaN(nextWidth) && nextWidth > 0) {
      this.pageWidth = nextWidth;
    }
    if (!Number.isNaN(nextHeight) && nextHeight > 0) {
      this.pageHeight = nextHeight;
    }
  }

  build() {
    Column() {
      ImmersiveBackChrome({
        title: this.level,
        subtitle: `${Math.min(this.currentWordIndex + 1, this.resultCount)} / ${this.resultCount}`,
        onBack: this.onBack,
        pageContent: () => {
          this.studyContent()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.updatePageSize(newArea.width, newArea.height);
    })
  }

  @Builder
  private studyContent() {
    Column() {
      if (this.loadError.length > 0) {
        Text(this.loadError)
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
      } else if (this.resultCount === 0) {
        Column({ space: 10 }) {
          Text('当前范围没有单词')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
          Button('返回', {
            type: ButtonType.ROUNDED_RECTANGLE,
            stateEffect: true
          })
            .buttonStyle(ButtonStyleMode.NORMAL)
            .controlSize(ControlSize.NORMAL)
            .onClick(this.onBack)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Swiper() {
          LazyForEach(this.dataSource, (item: VocabularyEntry) => {
            this.wordScene(item)
          }, (item: VocabularyEntry) => item.id)
        }
        .index(this.currentWordIndex)
        .indicator(false)
        .loop(false)
        .duration(MOTION_DURATION)
        .curve(curves.springMotion(0.42, 0.86, 0.16))
        .cachedCount(2)
        .effectMode(EdgeEffect.Spring)
        .layoutWeight(1)
        .width('100%')
        .onChange((index: number) => this.updateCurrentWord(index))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private wordScene(item: VocabularyEntry) {
    if (this.useHorizontalLayout()) {
      Row({ space: 28 }) {
        this.wordArtwork(item)
        Column() {
          this.wordDetails(item)
          this.studyActions(item)
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, bottom: 12 })
      .alignItems(VerticalAlign.Center)
    } else {
      Column() {
        this.wordArtwork(item)
        this.wordDetails(item)
        this.studyActions(item)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, bottom: 8 })
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private wordDetails(item: VocabularyEntry) {
    Scroll() {
      Column() {
        Row() {
          Column({ space: 3 }) {
            Text(item.word)
              .width('100%')
              .fontSize(item.word.length > 8 ? 25 : 30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(item.word,
                (selection: string) => this.askSelection(selection, item)))
            Text(item.reading)
              .width('100%')
              .fontSize(15)
              .fontColor($r('app.color.ink_muted'))
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(item.reading,
                (selection: string) => this.askSelection(selection, item)))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          if (this.containsLearnedWord(item.id)) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(24)
              .fontColor([$r('app.color.success')])
              .accessibilityText('已学会')
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(item.meanings.join('；'))
          .width('100%')
          .fontSize(17)
          .lineHeight(27)
          .fontColor($r('app.color.ink'))
          .margin({ top: 14 })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(item.meanings.join('；'),
            (selection: string) => this.askSelection(selection, item)))

        if (item.example !== undefined) {
          Text(item.example?.japanese ?? '')
            .width('100%')
            .fontSize(16)
            .lineHeight(25)
            .fontColor($r('app.color.ink'))
            .margin({ top: 16 })
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(item.example?.japanese ?? '',
              (selection: string) => this.askSelection(selection, item)))
          Text(item.example?.english ?? '')
            .width('100%')
            .fontSize(13)
            .lineHeight(21)
            .fontColor($r('app.color.ink_muted'))
            .margin({ top: 3 })
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(item.example?.english ?? '',
              (selection: string) => this.askSelection(selection, item)))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: this.useHorizontalLayout() ? 6 : 18, bottom: 10 })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private studyActions(item: VocabularyEntry) {
    Row() {
      this.roundAction(
        $r('sys.symbol.checkmark_circle_fill'),
        this.containsLearnedWord(item.id) ? '已学' : '标记',
        false,
        52,
        () => this.toggleLearned(item))
      this.roundAction(
        $r('sys.symbol.book_pages_fill'),
        '造句',
        true,
        68,
        () => this.openWordChat(item, this.personalizedPrompt(item)))
      this.roundAction(
        $r('sys.symbol.message_fill'),
        this.conversationCount > 0 ? '继续' : '对话',
        false,
        52,
        () => this.openWordChat(item))
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Bottom)
    .padding({ top: 6, bottom: 8 })
  }

  @Builder
  private wordArtwork(item: VocabularyEntry) {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.watermark(item))
        .fontSize(item.word.length > 5 ? 92 : 142)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .opacity(0.075)
        .hitTestBehavior(HitTestMode.None)

      Column({ space: 5 }) {
        Text(item.word)
          .fontSize(this.wordFontSize(item))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(item.word,
            (selection: string) => this.askSelection(selection, item)))
        Text(item.reading)
          .fontSize(15)
          .fontColor($r('app.color.accent'))
          .textAlign(TextAlign.Center)
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(item.reading,
            (selection: string) => this.askSelection(selection, item)))
      }
      .padding({ left: 18, right: 18 })

      Row() {
        Text(item.common ? `${item.level}  常用` : item.level)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Top)
      .padding(18)
    }
    .width(this.artworkSize())
    .height(this.artworkSize())
    .borderRadius(28)
    .clip(true)
    .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.immersive_edge'), 0], [this.wordTone(item), 1]]
    })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${item.word}，${item.reading}`)
  }

  @Builder
  private roundAction(icon: Resource, label: string, emphasized: boolean, size: number, onAction: () => void) {
    Column({ space: 5 }) {
      Button({
        type: ButtonType.Circle,
        stateEffect: true
      }) {
        SymbolGlyph(icon)
          .fontSize(emphasized ? 29 : 23)
          .fontColor([emphasized ? Color.White : $r('app.color.ink')])
      }
      .width(size)
      .height(size)
      .buttonStyle(emphasized ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL)
      .accessibilityText(label)
      .onClick(onAction)

      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink'))
    }
    .width(82)
    .alignItems(HorizontalAlign.Center)
  }
}
