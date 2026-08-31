import { common } from '@kit.AbilityKit';
import { ChipGroup, ChipGroupItemOptions, ChipSize, curves } from '@kit.ArkUI';
import { FLOATING_TAB_CONTENT_INSET, MOTION_DURATION } from '../../common/AppTheme';
import { LearningJourney, VocabularyEntry } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { VocabularyDataSource } from '../../services/VocabularyDataSource';
import {
  LearnedVocabularySnapshot,
  VocabularyLearningStore
} from '../../services/VocabularyLearningStore';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

const VOCABULARY_LEVELS: string[] = ['N5', 'N4', 'N3', 'N2', 'N1'];

@Component
export struct VocabularyPage {
  journey: LearningJourney | undefined = undefined;
  @Prop searchActive: boolean = false;
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};
  onStudy: (level: string, wordId: string, wordIds: string[]) => void =
    (level: string, wordId: string, wordIds: string[]) => {};
  onSearchActiveChange: (active: boolean) => void = (active: boolean) => {};

  @State private level: string = 'N5';
  @State private source: VocabularyEntry[] = [];
  @State private filtered: VocabularyEntry[] = [];
  @State private query: string = '';
  @State private resultCount: number = 0;
  @State private loadError: string = '';
  @State private learnedWords: LearnedVocabularySnapshot[] = [];
  @State private heroIndex: number = 0;
  @State private pageWidth: number = 360;
  private dataSource: VocabularyDataSource = new VocabularyDataSource();
  private learnedWordIds: Set<string> = new Set<string>();

  aboutToAppear(): void {
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    this.learnedWords = VocabularyLearningStore.loadLearnedWords(context);
    this.rebuildLearnedIndex(this.learnedWords);
    this.level = this.journey?.vocabularyLevel ?? 'N5';
    this.loadLevel(this.level);
  }

  private loadLevel(level: string): void {
    try {
      this.level = level;
      this.source = ContentRepository.loadVocabulary(
        this.getUIContext().getHostContext() as common.Context, level);
      this.loadError = '';
      this.applyFilter();
    } catch (error) {
      this.source = [];
      this.filtered = [];
      this.resultCount = 0;
      this.dataSource.reset([]);
      this.loadError = `${level} 词库没有正确载入`;
    }
  }

  private applyFilter(): void {
    const needle: string = this.query.trim().toLowerCase();
    const results: VocabularyEntry[] = [];
    for (let index: number = 0; index < this.source.length; index++) {
      const item: VocabularyEntry = this.source[index];
      const matches: boolean = needle.length === 0 ||
        `${item.word}\n${item.reading}\n${item.meanings.join(' ')}`.toLowerCase().includes(needle);
      if (matches) {
        results.push(item);
      }
    }
    this.filtered = results;
    this.resultCount = results.length;
    this.dataSource.reset(results);
  }

  private rebuildLearnedIndex(words: LearnedVocabularySnapshot[]): void {
    this.learnedWordIds.clear();
    for (let index: number = 0; index < words.length; index++) {
      this.learnedWordIds.add(words[index].id);
    }
  }

  private containsLearnedWord(id: string): boolean {
    return this.learnedWordIds.has(id);
  }

  private learnedInLevel(): number {
    let count: number = 0;
    for (let index: number = 0; index < this.source.length; index++) {
      if (this.containsLearnedWord(this.source[index].id)) {
        count++;
      }
    }
    return count;
  }

  private entriesToIds(items: VocabularyEntry[]): string[] {
    const ids: string[] = [];
    for (let index: number = 0; index < items.length; index++) {
      ids.push(items[index].id);
    }
    return ids;
  }

  private firstStudyWord(items: VocabularyEntry[]): string {
    for (let index: number = 0; index < items.length; index++) {
      if (!this.containsLearnedWord(items[index].id)) {
        return items[index].id;
      }
    }
    return items.length > 0 ? items[0].id : '';
  }

  private openLevelDeck(): void {
    if (this.source.length === 0) {
      return;
    }
    this.onStudy(this.level, this.firstStudyWord(this.source), this.entriesToIds(this.source));
  }

  private openJourneyDeck(): void {
    if (this.journey === undefined || this.journey.wordIds.length === 0) {
      return;
    }
    let firstId: string = this.journey.wordIds[0];
    for (let index: number = 0; index < this.journey.wordIds.length; index++) {
      if (!this.containsLearnedWord(this.journey.wordIds[index])) {
        firstId = this.journey.wordIds[index];
        break;
      }
    }
    this.onStudy(this.journey.vocabularyLevel, firstId, this.journey.wordIds.slice());
  }

  private askSelection(selection: string, item: VocabularyEntry): void {
    this.onAsk(AiInquiryFactory.selection(
      selection,
      `${item.level} 词库 · ${item.word}`,
      `读音：${item.reading}\n释义：${item.meanings.join('；')}`));
  }

  private levelTone(level: string): ResourceColor {
    switch (level) {
      case 'N5':
        return $r('app.color.word_card_blue');
      case 'N4':
        return $r('app.color.word_card_cyan');
      case 'N3':
        return $r('app.color.word_card_green');
      case 'N2':
        return $r('app.color.word_card_amber');
      default:
        return $r('app.color.word_card_rose');
    }
  }

  private wordTone(item: VocabularyEntry): ResourceColor {
    let hash: number = 0;
    for (let index: number = 0; index < item.id.length; index++) {
      hash = (hash * 31 + item.id.charCodeAt(index)) & 0x7fffffff;
    }
    switch (hash % 6) {
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

  private sampleWords(): string {
    const words: string[] = [];
    for (let index: number = 0; index < Math.min(4, this.source.length); index++) {
      words.push(this.source[index].word);
    }
    return words.join('  ');
  }

  private recentLearnedEntries(): VocabularyEntry[] {
    const entries: VocabularyEntry[] = [];
    for (let learnedIndex: number = this.learnedWords.length - 1;
      learnedIndex >= 0 && entries.length < 4; learnedIndex--) {
      for (let sourceIndex: number = 0; sourceIndex < this.source.length; sourceIndex++) {
        if (this.source[sourceIndex].id === this.learnedWords[learnedIndex].id) {
          entries.push(this.source[sourceIndex]);
          break;
        }
      }
    }
    return entries;
  }

  private heroDisplayCount(): number {
    return this.pageWidth >= 700 && this.journey !== undefined ? 2 : 1;
  }

  private levelChipItems(): ChipGroupItemOptions[] {
    const items: ChipGroupItemOptions[] = [];
    for (let index: number = 0; index < VOCABULARY_LEVELS.length; index++) {
      const level: string = VOCABULARY_LEVELS[index];
      items.push({
        label: { text: level },
        accessibilityDescription: `切换到 ${level} 词库`
      });
    }
    return items;
  }

  private selectedLevelIndexes(): number[] {
    const index: number = VOCABULARY_LEVELS.indexOf(this.level);
    return [index >= 0 ? index : 0];
  }

  private selectLevelIndexes(indexes: number[]): void {
    if (indexes.length === 0) {
      return;
    }
    const index: number = indexes[indexes.length - 1];
    if (index < 0 || index >= VOCABULARY_LEVELS.length) {
      return;
    }
    const nextLevel: string = VOCABULARY_LEVELS[index];
    if (nextLevel === this.level) {
      return;
    }
    this.query = '';
    this.heroIndex = 0;
    this.loadLevel(nextLevel);
  }

  private updatePageWidth(width: Length): void {
    const next: number = typeof width === 'number' ? width : Number.parseFloat(width as string);
    if (!Number.isNaN(next) && next > 0) {
      this.pageWidth = next;
    }
  }

  private openSearch(): void {
    this.query = '';
    this.applyFilter();
    this.onSearchActiveChange(true);
  }

  build() {
    Column() {
      if (this.searchActive) {
        PageChrome({
          largeTitle: false,
          customTitle: true,
          customTitleContent: () => {
            this.searchTitleContent()
          }
        })
      } else {
        PageChrome({
          title: '词库',
          largeTitle: false,
          showSearchAction: true,
          onSearch: () => this.openSearch()
        })

        ChipGroup({
          items: this.levelChipItems(),
          selectedIndexes: this.selectedLevelIndexes(),
          multiple: false,
          itemStyle: {
            size: ChipSize.NORMAL
          },
          chipGroupSpace: {
            itemSpace: 8,
            startSpace: 20,
            endSpace: 20
          },
          chipGroupPadding: {
            top: 2,
            bottom: 2
          },
          onChange: (indexes: number[]) => this.selectLevelIndexes(indexes)
        })
        .width('100%')
        .padding({ bottom: 14 })
      }

      if (this.loadError.length > 0) {
        Text(this.loadError)
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
      } else if (this.searchActive) {
        this.searchResults()
      } else {
        this.vocabularyHome()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .onAreaChange((oldArea: Area, newArea: Area) => this.updatePageWidth(newArea.width))
  }

  @Builder
  private searchTitleContent() {
    Row() {
      Search({ value: this.query, placeholder: '搜索单词、读音或释义' })
        .width('100%')
        .height(40)
        .defaultFocus(true)
        .textFont({ size: 15 })
        .fontColor($r('app.color.ink'))
        .placeholderColor($r('app.color.ink_muted'))
        .cancelButton({ style: CancelButtonStyle.INPUT })
        .caretStyle({ width: 2, color: $r('app.color.accent') })
        .selectedBackgroundColor($r('app.color.accent_soft'))
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => {
          this.query = value;
          this.applyFilter();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private vocabularyHome() {
    List({ space: 0 }) {
      ListItem() {
        Swiper() {
          this.levelDeck()
          if (this.journey !== undefined) {
            this.journeyDeck()
          }
        }
        .index(this.heroIndex)
        .displayCount(this.heroDisplayCount())
        .nextMargin(this.heroDisplayCount() === 1 && this.journey !== undefined ? 34 : 0, true)
        .indicator(false)
        .loop(false)
        .duration(MOTION_DURATION)
        .curve(curves.springMotion(0.42, 0.86, 0.16))
        .itemSpace(this.heroDisplayCount() === 1 ? 12 : 16)
        .height(286)
        .width('100%')
        .padding({ left: 20, right: this.heroDisplayCount() === 1 ? 0 : 20 })
        .onChange((index: number) => this.heroIndex = index)
      }

      if (this.recentLearnedEntries().length > 0) {
        ListItem() {
          Column() {
            Text('最近已学')
              .width('100%')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .margin({ bottom: 8 })

            ForEach(this.recentLearnedEntries(), (item: VocabularyEntry) => {
              this.wordRow(item, this.source)
            }, (item: VocabularyEntry) => item.id)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 28 })
        }
      }

      ListItem() {
        Column()
          .height(FLOATING_TAB_CONTENT_INSET)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private levelDeck() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Text(this.level)
        .fontSize(136)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .opacity(0.075)
        .position({ x: 124, y: -18 })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Text(`${this.level} 词汇`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
        Blank()
        Text('基础词库')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.sampleWords())
          .width('100%')
          .fontSize(15)
          .fontColor($r('app.color.ink_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Row() {
          Text(`${this.source.length} 个单词`)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
          Text(`已学 ${this.learnedInLevel()}`)
            .fontSize(12)
            .fontColor($r('app.color.success'))
            .margin({ left: 12 })
          Blank()
          Button(this.learnedInLevel() > 0 ? '继续' : '开始', {
            type: ButtonType.ROUNDED_RECTANGLE,
            stateEffect: true
          })
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .controlSize(ControlSize.NORMAL)
            .onClick(() => this.openLevelDeck())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 18 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .borderRadius(28)
    .clip(true)
    .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.immersive_edge'), 0], [this.levelTone(this.level), 1]]
    })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${this.level} 基础词库，共 ${this.source.length} 个单词`)
    .onClick(() => this.openLevelDeck())
  }

  @Builder
  private journeyDeck() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Text(this.journey?.japaneseTitle ?? '')
        .fontSize(74)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .opacity(0.065)
        .position({ x: 72, y: 8 })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Text('当前旅程')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
        Blank()
        Text(this.journey?.title ?? '')
          .width('100%')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.journey?.wordIds.length ?? 0} 个核心词`)
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
          .margin({ top: 7 })
        Row() {
          Text(this.journey?.setting ?? '')
            .layoutWeight(1)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Button('进入', {
            type: ButtonType.ROUNDED_RECTANGLE,
            stateEffect: true
          })
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .controlSize(ControlSize.NORMAL)
            .onClick(() => this.openJourneyDeck())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 18 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .borderRadius(28)
    .clip(true)
    .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.immersive_edge'), 0], [$r('app.color.word_card_violet'), 1]]
    })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`当前旅程，${this.journey?.title ?? ''}`)
    .onClick(() => this.openJourneyDeck())
  }

  @Builder
  private searchResults() {
    Column() {
      Row() {
        Text(this.query.trim().length > 0 ? '搜索结果' : `${this.level} 单词`)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Blank()
        Text(`${this.resultCount} 个`)
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 8 })

      if (this.resultCount === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(30)
            .fontColor([$r('app.color.ink_muted')])
          Text('没有匹配的单词')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          LazyForEach(this.dataSource, (item: VocabularyEntry) => {
            ListItem() {
              this.wordRow(item, this.filtered)
            }
          }, (item: VocabularyEntry) => item.id)
          ListItem() {
            Column()
              .height(FLOATING_TAB_CONTENT_INSET)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 20, right: 20 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  private wordRow(item: VocabularyEntry, scope: VocabularyEntry[]) {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(item.word.length > 2 ? item.word.slice(0, 2) : item.word)
          .fontSize(item.word.length > 4 ? 17 : 22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
      }
      .width(64)
      .height(64)
      .borderRadius(18)
      .clip(true)
      .linearGradient({
        angle: 180,
        colors: [[$r('app.color.immersive_edge'), 0], [this.wordTone(item), 1]]
      })
      .visualEffect(planeLightEffect())

      Column({ space: 3 }) {
        Text(item.word)
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(item.word,
            (selection: string) => this.askSelection(selection, item)))
        Text(`${item.reading}  ${item.meanings.slice(0, 1).join('')}`)
          .width('100%')
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(`${item.reading}  ${item.meanings.slice(0, 1).join('')}`,
            (selection: string) => this.askSelection(selection, item)))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.containsLearnedWord(item.id)) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.success')])
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(19)
          .fontColor([$r('app.color.ink_muted')])
      }
    }
    .width('100%')
    .height(84)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onStudy(this.level, item.id, this.entriesToIds(scope)))
  }
}
