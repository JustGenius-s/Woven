import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import {
  ContentManifest,
  KanaCell,
  KanaRow,
  LearningCatalog,
  ReadingWork
} from '../../model/ContentModels';
import { GrammarWork } from '../../model/GrammarModels';
import { ContentRepository } from '../../services/ContentRepository';
import { FloatingBarScrollTracker } from '../components/FloatingBarScrollTracker';
import { planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

@Component
export struct LearnPage {
  kanaKey: string = 'あ';
  learnedWordCount: number = 0;
  videoCount: number = 0;
  lastVideoTitle: string = '';
  readingIndex: number = -1;
  scenarioIndex: number = -1;
  grammarId: string = '';
  onScrollerReady: (scroller: Scroller) => void = (scroller: Scroller) => {};
  onFloatingBarCompactChange: (compact: boolean) => void = (compact: boolean) => {};
  onOpenKana: () => void = () => {};
  onOpenVocabulary: () => void = () => {};
  onOpenExplore: (tab: number) => void = (tab: number) => {};
  onOpenGrammar: () => void = () => {};

  @State private grammarWorks: GrammarWork[] = [];
  @State private catalog: LearningCatalog | undefined = undefined;
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
      this.grammarWorks = ContentRepository.loadGrammarWorks(context);
      this.catalog = ContentRepository.loadCatalog(context);
      this.readingWorks = ContentRepository.loadReadingWorks(context);
      this.manifest = ContentRepository.loadManifest(context);
      this.loadError = '';
      void this.refreshReadings(context);
      void this.refreshGrammar(context);
    } catch (error) {
      this.loadError = '学习进度没有正确载入';
    }
  }

  private async refreshReadings(context: common.Context): Promise<void> {
    try {
      this.readingWorks = await ContentRepository.prefetchReadings(context);
    } catch (error) {
      // Keep the last catalog if the network is offline.
    }
  }

  private async refreshGrammar(context: common.Context): Promise<void> {
    try {
      this.grammarWorks = await ContentRepository.prefetchGrammar(context);
    } catch (error) {
      // Keep the cached Irodori list if the catalog is offline.
    }
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

  private currentGrammar(): GrammarWork | undefined {
    for (let index: number = 0; index < this.grammarWorks.length; index++) {
      if (this.grammarWorks[index].id === this.grammarId) {
        return this.grammarWorks[index];
      }
    }
    return undefined;
  }

  private grammarDetail(): string {
    const lesson: GrammarWork | undefined = this.currentGrammar();
    if (lesson === undefined) {
      return this.grammarWorks.length > 0 ? 'Irodori 生活の日本語' : '尚未开始';
    }
    return lesson.titleJa.length > 0 ? lesson.titleJa : lesson.title;
  }

  private grammarCaption(): string {
    const lesson: GrammarWork | undefined = this.currentGrammar();
    if (lesson === undefined) {
      return '入门 · 初级1 · 初级2 · 初中级';
    }
    return lesson.lessonNo === 0 ? lesson.level : `${lesson.level} · 第 ${lesson.lessonNo} 课`;
  }

  private grammarProgressIndex(): number {
    const lesson: GrammarWork | undefined = this.currentGrammar();
    if (lesson === undefined) {
      return 0;
    }
    for (let index: number = 0; index < this.grammarWorks.length; index++) {
      if (this.grammarWorks[index].id === lesson.id) {
        return index + 1;
      }
    }
    return 0;
  }

  private videoHeadline(): string {
    return this.lastVideoTitle.length > 0 ? this.lastVideoTitle : '尚未添加';
  }

  private videoCaption(): string {
    return this.videoCount > 0 ? `${this.videoCount} 个视频` : '用链接或本地文件添加';
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
    this.progressHome()
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
              '文法',
              this.grammarDetail(),
              this.grammarCaption(),
              `${this.grammarProgressIndex()} / ${this.grammarWorks.length}`,
              $r('app.media.journey_grammar'),
              $r('sys.symbol.bookmark_fill'),
              $r('app.color.word_card_green'),
              this.progress(this.grammarProgressIndex(), this.grammarWorks.length),
              () => this.onOpenGrammar())
          }

          ListItem() {
            this.journeyCard(
              3,
              '视频',
              this.videoHeadline(),
              this.videoCaption(),
              `${this.videoCount}`,
              $r('app.media.journey_music'),
              $r('sys.symbol.play_circle_fill'),
              $r('app.color.word_card_amber'),
              this.progress(this.videoCount, Math.max(1, this.videoCount)),
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
