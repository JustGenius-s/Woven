import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { OperationType, SubHeader } from '@ohos.arkui.advanced.SubHeader';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { LearningJourney, VocabularyEntry } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { JapaneseTtsService } from '../../services/JapaneseTtsService';
import { PitchNotation } from '../../services/PitchNotation';
import { VocabularyDataSource } from '../../services/VocabularyDataSource';
import {
  LearnedVocabularySnapshot,
  VocabularyLearningStore
} from '../../services/VocabularyLearningStore';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { FloatingBarScrollTracker } from '../components/FloatingBarScrollTracker';
import {
  ContentShelf,
  SHELF_LEVEL_HEIGHT,
  SHELF_LEVEL_WIDTH
} from '../components/ContentShelf';
import { CoverCard } from '../components/CoverCard';
import { planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

const VOCABULARY_LEVELS: string[] = ['N5', 'N4', 'N3', 'N2', 'N1', '日常', '一般', '补遗'];

@Component
export struct VocabularyPage {
  journey: LearningJourney | undefined = undefined;
  @Prop searchActive: boolean = false;
  onScrollerReady: (scroller: Scroller) => void = (scroller: Scroller) => {};
  onFloatingBarCompactChange: (compact: boolean) => void = (compact: boolean) => {};
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
  @State private levelCounts: number[] = [];
  private dataSource: VocabularyDataSource = new VocabularyDataSource();
  private learnedWordIds: Set<string> = new Set<string>();
  private homeScroller: Scroller = new Scroller();
  private searchScroller: Scroller = new Scroller();
  private homeFloatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('vocabulary-home');
  private searchFloatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('vocabulary-search');

  aboutToAppear(): void {
    this.onScrollerReady(this.homeScroller);
    this.onScrollerReady(this.searchScroller);
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    JapaneseTtsService.initialize(context);
    this.learnedWords = VocabularyLearningStore.loadLearnedWords(context);
    this.rebuildLearnedIndex(this.learnedWords);
    this.level = this.journey?.vocabularyLevel ?? 'N5';
    this.loadLevel(this.level);
    this.loadLevelCounts(context);
  }

  private loadLevelCounts(context: common.Context): void {
    const counts: number[] = [];
    for (let index: number = 0; index < VOCABULARY_LEVELS.length; index++) {
      try {
        counts.push(ContentRepository.loadVocabulary(context, VOCABULARY_LEVELS[index]).length);
      } catch (_error) {
        counts.push(0);
      }
    }
    this.levelCounts = counts;
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

  private openLevelCover(level: string): void {
    if (level !== this.level) {
      this.query = '';
      this.loadLevel(level);
    }
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

  private levelCaption(level: string = this.level): string {
    switch (level) {
      case '日常':
        return '高频常用';
      case '一般':
        return '中低频常用';
      case '补遗':
        return '编辑补遗';
      default:
        return '基础词库';
    }
  }

  private levelArtwork(level: string): Resource {
    switch (level) {
      case 'N5':
        return $r('app.media.vocabulary_n5');
      case 'N4':
        return $r('app.media.vocabulary_n4');
      case 'N3':
        return $r('app.media.vocabulary_n3');
      case 'N2':
        return $r('app.media.vocabulary_n2');
      case 'N1':
        return $r('app.media.vocabulary_n1');
      case '日常':
        return $r('app.media.vocabulary_daily');
      case '一般':
        return $r('app.media.vocabulary_general');
      case '补遗':
        return $r('app.media.vocabulary_supplement');
      default:
        return $r('app.media.vocabulary_n5');
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

  private wordSubtitle(item: VocabularyEntry): string {
    const pitch: string = PitchNotation.summary(item);
    const meaning: string = item.meanings.slice(0, 1).join('');
    return pitch.length > 0 ? `${item.reading}  ${pitch}  ${meaning}` :
      `${item.reading}  ${meaning}`;
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

  private levelCount(index: number): number {
    if (index < 0 || index >= this.levelCounts.length) {
      return 0;
    }
    return this.levelCounts[index];
  }

  private vocabularyTotal(): number {
    let total: number = 0;
    for (let index: number = 0; index < this.levelCounts.length; index++) {
      total += this.levelCounts[index];
    }
    return total;
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
          scrollers: [this.homeScroller, this.searchScroller],
          customTitleContent: () => {
            this.searchTitleContent()
          },
          pageContent: () => {
            this.vocabularyContent()
          }
        })
      } else {
        PageChrome({
          title: '词库',
          largeTitle: false,
          showSearchAction: true,
          scrollers: [this.homeScroller, this.searchScroller],
          onSearch: () => this.openSearch(),
          pageContent: () => {
            this.vocabularyContent()
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private vocabularyContent() {
    Column() {
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
    List({ space: 8, scroller: this.homeScroller }) {
      if (this.journey !== undefined) {
        ListItem() {
          this.journeyShelf()
        }
      }

      ListItem() {
        this.levelShelf()
      }

      if (this.recentLearnedEntries().length > 0) {
        ListItem() {
          Column() {
            SubHeader({
              primaryTitle: '最近已学',
              operationType: OperationType.BUTTON,
              operationItem: [{ value: `${this.recentLearnedEntries().length} 个` }],
              contentMargin: {
                start: LengthMetrics.vp(16),
                end: LengthMetrics.vp(16)
              }
            })
            Column() {
              ForEach(this.recentLearnedEntries(), (item: VocabularyEntry) => {
                this.wordRow(item, this.source)
              }, (item: VocabularyEntry) => item.id)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
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
    .clip(false)
    .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) =>
      this.homeFloatingBarTracker.update(this.homeScroller, this.onFloatingBarCompactChange))
  }

  @Builder
  private journeyShelf() {
    Column() {
      ContentShelf({
        title: '当前旅程',
        meta: `${this.journey?.wordIds.length ?? 0} 个核心词`
      })
      Scroll() {
        Row({ space: 10 }) {
          Column() {
            CoverCard({
              artwork: $r('app.media.journey_vocabulary'),
              badge: '旅程',
              title: this.journey?.title ?? '',
              subtitle: this.journey?.setting ?? '',
              compact: true,
              cardWidth: SHELF_LEVEL_WIDTH,
              cardHeight: SHELF_LEVEL_HEIGHT,
              onOpen: () => this.openJourneyDeck()
            })
          }
          .width(SHELF_LEVEL_WIDTH)
          .height(SHELF_LEVEL_HEIGHT)
        }
        .height(SHELF_LEVEL_HEIGHT)
        .alignItems(VerticalAlign.Top)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(SHELF_LEVEL_HEIGHT)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private levelShelf() {
    Column() {
      ContentShelf({
        title: '词库',
        meta: `${this.vocabularyTotal()} 个词`
      })
      Scroll() {
        Row({ space: 10 }) {
          ForEach(VOCABULARY_LEVELS, (level: string, index: number) => {
            Column() {
              CoverCard({
                artwork: this.levelArtwork(level),
                badge: level,
                meta: `${this.levelCount(index)} 个`,
                title: this.levelCaption(level),
                compact: true,
                cardWidth: SHELF_LEVEL_WIDTH,
                cardHeight: SHELF_LEVEL_HEIGHT,
                onOpen: () => this.openLevelCover(level)
              })
            }
            .width(SHELF_LEVEL_WIDTH)
            .height(SHELF_LEVEL_HEIGHT)
          }, (level: string) => level)
        }
        .height(SHELF_LEVEL_HEIGHT)
        .alignItems(VerticalAlign.Top)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(SHELF_LEVEL_HEIGHT)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private searchResults() {
    Column() {
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
        List({ space: 0, scroller: this.searchScroller }) {
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
        .clip(false)
        .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) =>
          this.searchFloatingBarTracker.update(this.searchScroller, this.onFloatingBarCompactChange))
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
        colors: [[$r('app.color.surface_raised'), 0], [this.wordTone(item), 1]]
      })
      .visualEffect(planeLightEffect())
      .onClick(() => this.onStudy(this.level, item.id, this.entriesToIds(scope)))

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
        Text(this.wordSubtitle(item))
          .width('100%')
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(this.wordSubtitle(item),
            (selection: string) => this.askSelection(selection, item)))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => this.onStudy(this.level, item.id, this.entriesToIds(scope)))

      Button({
        type: ButtonType.Circle,
        stateEffect: true
      }) {
        SymbolGlyph($r('sys.symbol.speaker_wave_2_fill'))
          .fontSize(18)
          .fontColor([$r('app.color.ink_muted')])
      }
      .width(40)
      .height(40)
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .accessibilityText(`朗读 ${item.word}`)
      .onClick(() => JapaneseTtsService.playEntry(item.word, item.reading))

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
  }
}
