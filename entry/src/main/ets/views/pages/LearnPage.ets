import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import {
  ContentManifest,
  GrammarIndexEntry,
  KanaCell,
  KanaRow,
  LearningCatalog,
  MusicTrack,
  ReadingWork
} from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { ContentRepository } from '../../services/ContentRepository';
import { FloatingBarScrollTracker } from '../components/FloatingBarScrollTracker';
import { planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';
import { GrammarPage } from './GrammarPage';

@Component
export struct LearnPage {
  savedLessonIndex: number = 0;
  kanaKey: string = 'あ';
  learnedWordCount: number = 0;
  musicIndex: number = -1;
  readingIndex: number = -1;
  scenarioIndex: number = -1;
  onScrollerReady: (scroller: Scroller) => void = (scroller: Scroller) => {};
  onFloatingBarCompactChange: (compact: boolean) => void = (compact: boolean) => {};
  onLessonChange: (index: number) => void = (index: number) => {};
  onOpenKana: () => void = () => {};
  onOpenVocabulary: () => void = () => {};
  onOpenExplore: (tab: number) => void = (tab: number) => {};
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};

  @State private mode: number = 0;
  @State private grammarIndex: GrammarIndexEntry[] = [];
  @State private catalog: LearningCatalog | undefined = undefined;
  @State private musicTracks: MusicTrack[] = [];
  @State private readingWorks: ReadingWork[] = [];
  @State private manifest: ContentManifest | undefined = undefined;
  @State private loadError: string = '';
  @State private pressedCard: number = -1;
  private progressScroller: Scroller = new Scroller();
  private floatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('learn');

  aboutToAppear(): void {
    this.onScrollerReady(this.progressScroller);
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.grammarIndex = ContentRepository.loadGrammarIndex(context);
      this.catalog = ContentRepository.loadCatalog(context);
      this.musicTracks = ContentRepository.loadMusicTracks(context);
      this.readingWorks = ContentRepository.loadReadingWorks(context);
      this.manifest = ContentRepository.loadManifest(context);
      this.loadError = '';
    } catch (error) {
      this.loadError = '学习进度没有正确载入';
    }
  }

  private changeMode(mode: number): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.4, 0.86, 0.16) }, () => {
      this.mode = mode;
    });
  }

  private clampIndex(index: number, count: number): number {
    if (count <= 0) {
      return -1;
    }
    return Math.max(0, Math.min(index, count - 1));
  }

  private progress(current: number, total: number): number {
    if (total <= 0 || current <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(1, current / total));
  }

  private kanaCells(): KanaCell[] {
    const cells: KanaCell[] = [];
    if (this.catalog === undefined) {
      return cells;
    }
    const groups: KanaRow[][] = [
      this.catalog.kanaGroups.basic,
      this.catalog.kanaGroups.voiced,
      this.catalog.kanaGroups.contracted
    ];
    for (let groupIndex: number = 0; groupIndex < groups.length; groupIndex++) {
      for (let rowIndex: number = 0; rowIndex < groups[groupIndex].length; rowIndex++) {
        const row: KanaRow = groups[groupIndex][rowIndex];
        for (let cellIndex: number = 0; cellIndex < row.cells.length; cellIndex++) {
          cells.push(row.cells[cellIndex]);
        }
      }
    }
    return cells;
  }

  private kanaIndex(): number {
    const cells: KanaCell[] = this.kanaCells();
    for (let index: number = 0; index < cells.length; index++) {
      if (cells[index].key === this.kanaKey) {
        return index;
      }
    }
    return cells.length > 0 ? 0 : -1;
  }

  private kanaDetail(): string {
    const cells: KanaCell[] = this.kanaCells();
    const index: number = this.kanaIndex();
    if (index < 0 || index >= cells.length) {
      return '尚未开始';
    }
    const cell: KanaCell = cells[index];
    return `${cell.hira} / ${cell.kata}`;
  }

  private kanaCaption(): string {
    const cells: KanaCell[] = this.kanaCells();
    const index: number = this.kanaIndex();
    return index >= 0 && index < cells.length ? `发音 ${cells[index].romaji}` : '从清音开始';
  }

  private grammarDetail(): string {
    const index: number = this.clampIndex(this.savedLessonIndex, this.grammarIndex.length);
    return index >= 0 ? this.grammarIndex[index].title : '尚未开始';
  }

  private grammarCaption(): string {
    const index: number = this.clampIndex(this.savedLessonIndex, this.grammarIndex.length);
    return index >= 0 ? `${this.grammarIndex[index].level} · 第 ${index + 1} 课` : '尚未开始';
  }

  private musicHeadline(): string {
    const index: number = this.clampIndex(this.musicIndex, this.musicTracks.length);
    return this.musicIndex >= 0 && index >= 0 ? this.musicTracks[index].title : '尚未开始';
  }

  private musicCaption(): string {
    const index: number = this.clampIndex(this.musicIndex, this.musicTracks.length);
    return this.musicIndex >= 0 && index >= 0 ?
      `${this.musicTracks[index].chineseTitle} · ${this.musicTracks[index].artist}` :
      `${this.musicTracks.length} 首日语学习音乐`;
  }

  private readingHeadline(): string {
    const index: number = this.clampIndex(this.readingIndex, this.readingWorks.length);
    return this.readingIndex >= 0 && index >= 0 ? this.readingWorks[index].title : '尚未开始';
  }

  private readingCaption(): string {
    const index: number = this.clampIndex(this.readingIndex, this.readingWorks.length);
    return this.readingIndex >= 0 && index >= 0 ?
      `${this.readingWorks[index].author} · ${this.readingWorks[index].level}` :
      `${this.readingWorks.length} 篇开放阅读`;
  }

  private scenarioHeadline(): string {
    const scenarios = this.catalog?.practiceScenarios ?? [];
    const index: number = this.clampIndex(this.scenarioIndex, scenarios.length);
    return this.scenarioIndex >= 0 && index >= 0 ? scenarios[index].title : '尚未开始';
  }

  private scenarioCaption(): string {
    const scenarios = this.catalog?.practiceScenarios ?? [];
    const index: number = this.clampIndex(this.scenarioIndex, scenarios.length);
    return this.scenarioIndex >= 0 && index >= 0 ? scenarios[index].setting : `${scenarios.length} 个日常场景`;
  }

  private vocabularyTotal(): number {
    return this.manifest?.vocabulary.lexiconTotal ?? this.manifest?.vocabulary.total ?? 0;
  }

  private progressWidth(progress: number): string {
    const percent: number = Math.round(Math.max(0, Math.min(1, progress)) * 100);
    return `${progress > 0 ? Math.max(3, percent) : 0}%`;
  }

  private progressPercent(progress: number): string {
    const percent: number = Math.max(0, Math.min(1, progress)) * 100;
    if (percent > 0 && percent < 1) {
      return '<1%';
    }
    return `${Math.round(percent)}%`;
  }

  build() {
    if (this.mode === 1) {
      GrammarPage({
        entries: this.grammarIndex,
        initialIndex: this.savedLessonIndex,
        onIndexChange: this.onLessonChange,
        onAsk: this.onAsk,
        onBack: () => this.changeMode(0)
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ x: 20 }))
        .animation({ curve: curves.springMotion(0.4, 0.86, 0.16) }))
    } else {
      this.progressHome()
    }
  }

  @Builder
  private progressHome() {
    PageChrome({
      title: '旅程',
      scrollers: [this.progressScroller],
      pageContent: () => {
        this.progressHomeContent()
      }
    })
  }

  @Builder
  private progressHomeContent() {
    if (this.loadError.length > 0) {
        Text(this.loadError)
          .width('100%')
          .height('100%')
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
    } else {
        List({ space: 14, scroller: this.progressScroller }) {
          ListItem() {
            this.journeyCard(
              0,
              '五十音图',
              this.kanaDetail(),
              this.kanaCaption(),
              `${Math.max(0, this.kanaIndex() + 1)} / ${this.kanaCells().length}`,
              $r('app.media.journey_kana'),
              $r('sys.symbol.character_square_fill'),
              $r('app.color.word_card_blue'),
              this.progress(this.kanaIndex() + 1, this.kanaCells().length),
              () => this.onOpenKana())
          }

          ListItem() {
            this.journeyCard(
              1,
              '单词',
              `已学 ${this.learnedWordCount} 个单词`,
              '考试词与常用词',
              `${this.learnedWordCount} / ${this.vocabularyTotal()}`,
              $r('app.media.journey_vocabulary'),
              $r('sys.symbol.translate_square_fill'),
              $r('app.color.word_card_cyan'),
              this.progress(this.learnedWordCount, this.vocabularyTotal()),
              () => this.onOpenVocabulary())
          }

          ListItem() {
            this.journeyCard(
              2,
              '语法',
              this.grammarDetail(),
              this.grammarCaption(),
              `${Math.min(this.savedLessonIndex + 1, this.grammarIndex.length)} / ${this.grammarIndex.length}`,
              $r('app.media.journey_grammar'),
              $r('sys.symbol.bookmark_fill'),
              $r('app.color.word_card_green'),
              this.progress(this.savedLessonIndex + 1, this.grammarIndex.length),
              () => this.changeMode(1))
          }

          ListItem() {
            this.journeyCard(
              3,
              '音乐',
              this.musicHeadline(),
              this.musicCaption(),
              `${this.musicIndex < 0 ? 0 : Math.min(this.musicIndex + 1, this.musicTracks.length)} / ${this.musicTracks.length}`,
              $r('app.media.journey_music'),
              $r('sys.symbol.music_note_circle_fill'),
              $r('app.color.word_card_amber'),
              this.progress(this.musicIndex + 1, this.musicTracks.length),
              () => this.onOpenExplore(0))
          }

          ListItem() {
            this.journeyCard(
              4,
              '阅读',
              this.readingHeadline(),
              this.readingCaption(),
              `${this.readingIndex < 0 ? 0 : Math.min(this.readingIndex + 1,
                this.readingWorks.length)} / ${this.readingWorks.length}`,
              $r('app.media.journey_reading'),
              $r('sys.symbol.book_pages_fill'),
              $r('app.color.word_card_rose'),
              this.progress(this.readingIndex + 1, this.readingWorks.length),
              () => this.onOpenExplore(1))
          }

          ListItem() {
            this.journeyCard(
              5,
              '场景',
              this.scenarioHeadline(),
              this.scenarioCaption(),
              `${this.scenarioIndex < 0 ? 0 : Math.min(this.scenarioIndex + 1,
                this.catalog?.practiceScenarios.length ?? 0)} / ${this.catalog?.practiceScenarios.length ?? 0}`,
              $r('app.media.journey_scenario'),
              $r('sys.symbol.person_2_fill'),
              $r('app.color.word_card_violet'),
              this.progress(this.scenarioIndex + 1, this.catalog?.practiceScenarios.length ?? 0),
              () => this.onOpenExplore(2))
          }
        }
        .layoutWeight(1)
        .width('100%')
        .constraintSize({ maxWidth: 720 })
        .padding({ left: 18, right: 18, top: 8, bottom: FLOATING_TAB_CONTENT_INSET })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .clip(false)
        .alignListItem(ListItemAlign.Center)
        .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) =>
          this.floatingBarTracker.update(this.progressScroller, this.onFloatingBarCompactChange))
    }
  }

  @Builder
  private journeyCard(index: number, title: string, headline: string, caption: string, meta: string,
    artwork: Resource, icon: Resource, tone: ResourceColor, progress: number, onSelect: () => void) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(artwork)
        .width(326)
        .height(218)
        .objectFit(ImageFit.Contain)
        .opacity(0.96)
        .margin({ top: -4, right: -36 })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row({ space: 10 }) {
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph(icon)
              .fontSize(19)
              .fontColor([$r('app.color.accent')])
          }
          .width(36)
          .height(36)
          .borderRadius(12)
          .backgroundColor($r('app.color.surface_raised'))

          Text(title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))

          Blank()

          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(17)
              .fontColor([$r('app.color.ink')])
          }
          .width(32)
          .height(32)
          .borderRadius(11)
          .backgroundColor($r('app.color.surface_raised'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Blank()

        Text(headline)
          .width('58%')
          .fontSize(25)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(caption)
          .width('56%')
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })

        Row() {
          Text(meta)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink_muted'))
          Blank()
          Text(this.progressPercent(progress))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
        }
        .width('58%')
        .margin({ top: 17 })

        Stack({ alignContent: Alignment.Start }) {
          Column()
            .width('100%')
            .height(3)
            .borderRadius(2)
            .backgroundColor($r('app.color.line'))
          Column()
            .width(this.progressWidth(progress))
            .height(3)
            .borderRadius(2)
            .backgroundColor($r('app.color.accent'))
        }
        .width('58%')
        .height(3)
        .margin({ top: 7 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
    }
    .width('100%')
    .height(210)
    .borderRadius(28)
    .clip(true)
    .backgroundColor(tone)
    .linearGradient({
      angle: 150,
      colors: [[tone, 0], [tone, 0.58], [$r('app.color.surface_raised'), 1]]
    })
    .shadow({ radius: 18, color: $r('app.color.journey_card_shadow'), offsetY: 8 })
    .visualEffect(planeLightEffect())
    .scale({ x: this.pressedCard === index ? 0.985 : 1, y: this.pressedCard === index ? 0.985 : 1 })
    .animation({ curve: curves.responsiveSpringMotion(0.18, 0.86, 0.12) })
    .accessibilityText(`${title}，${headline}，${caption}，${meta}`)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedCard = index;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedCard = -1;
      }
    })
    .onClick(onSelect)
  }
}
