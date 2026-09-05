import { common } from '@kit.AbilityKit';
import { SegmentButtonV2Items, TabSegmentButtonV2, uiMaterial } from '@kit.ArkUI';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { LearningJourney } from '../../model/ContentModels';
import { GrammarWork } from '../../model/GrammarModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { ContentRepository } from '../../services/ContentRepository';
import { ContentShelfDataSource } from '../../services/ContentShelfDataSource';
import { GrammarBookService } from '../../services/GrammarBookService';
import { FloatingBarScrollTracker } from '../components/FloatingBarScrollTracker';
import {
  ContentShelf,
  SHELF_COVER_HEIGHT,
  SHELF_COVER_WIDTH
} from '../components/ContentShelf';
import { CoverCard } from '../components/CoverCard';
import { PageChrome } from '../components/PageChrome';
import { KanaPage } from './KanaPage';

@Component
export struct BasicsPage {
  @Prop selectedTab: number = 0;
  @Prop grammarId: string = '';
  @Prop @Watch('onGrammarOpenChange') grammarOpen: boolean = false;
  journey: LearningJourney | undefined = undefined;
  initialKanaKey: string = 'あ';
  onScrollerReady: (scroller: Scroller) => void = (_scroller: Scroller) => {};
  onFloatingBarCompactChange: (compact: boolean) => void = (_compact: boolean) => {};
  onTabChange: (index: number) => void = (_index: number) => {};
  onAsk: (context: AiInquiryContext) => void = (_context: AiInquiryContext) => {};
  onKanaChange: (key: string) => void = (_key: string) => {};
  onOpenGrammar: (lesson: GrammarWork) => void = (_lesson: GrammarWork) => {};

  @State private basicsTabIndex: number = 0;
  @State private lessons: GrammarWork[] = [];
  @State private lessonsLoading: boolean = true;
  @State private loadError: string = '';
  @State private localStateVersion: number = 0;
  private basicsTabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '五十音' },
    { text: '文法' }
  ]);
  private grammarScroller: Scroller = new Scroller();
  private grammarFloatingBarTracker: FloatingBarScrollTracker =
    new FloatingBarScrollTracker('basics-grammar');
  private coverPaths: Map<string, string> = new Map();
  private downloadedLessonIds: Set<string> = new Set();
  private shelfSources: Map<string, ContentShelfDataSource<GrammarWork>> = new Map();
  private localStateGeneration: number = 0;
  private readonly lessonCategories: string[] = ['入门', '初级1', '初级2', '初中级'];

  aboutToAppear(): void {
    this.onScrollerReady(this.grammarScroller);
    this.basicsTabIndex = this.selectedTab;
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    void this.initializeLessons(context);
  }

  private async initializeLessons(context: common.Context): Promise<void> {
    this.lessonsLoading = true;
    this.lessons = await ContentRepository.loadGrammarWorksAsync(context);
    this.resetShelfSources();
    void this.refreshLocalState(context);
    await this.refreshLessons(context);
  }

  private async refreshLessons(context: common.Context): Promise<void> {
    this.lessonsLoading = this.lessons.length === 0;
    try {
      this.lessons = await ContentRepository.prefetchGrammar(context);
      this.resetShelfSources();
      await this.refreshLocalState(context);
      void this.downloadCovers(context);
      if (this.lessons.length > 0) {
        this.loadError = '';
      }
    } catch (error) {
      if (this.lessons.length === 0) {
        const detail: string = error instanceof Error ? error.message : '';
        this.loadError = detail.length > 0 ? `文法课表加载失败：${detail}` : '文法课表加载失败';
      }
    } finally {
      this.lessonsLoading = false;
    }
  }

  private async refreshLocalState(context: common.Context): Promise<void> {
    const generation: number = ++this.localStateGeneration;
    const lessons: GrammarWork[] = this.lessons.slice();
    const nextCovers: Map<string, string> = new Map();
    const nextDownloaded: Set<string> = new Set();
    for (let index: number = 0; index < lessons.length; index++) {
      const lesson: GrammarWork = lessons[index];
      const cover: string = await GrammarBookService.coverReadyAsync(context, lesson);
      if (cover.length > 0) {
        nextCovers.set(lesson.id, cover);
      }
      if (await GrammarBookService.isLessonReadyAsync(context, lesson)) {
        nextDownloaded.add(lesson.id);
      }
    }
    if (generation !== this.localStateGeneration) {
      return;
    }
    this.coverPaths = nextCovers;
    this.downloadedLessonIds = nextDownloaded;
    this.localStateVersion += 1;
    this.reloadShelfSources();
  }

  private async downloadCovers(context: common.Context): Promise<void> {
    let changed: boolean = false;
    for (let index: number = 0; index < this.lessons.length; index++) {
      const lesson: GrammarWork = this.lessons[index];
      if (lesson.coverKey === undefined || lesson.coverKey.length === 0) {
        continue;
      }
      if ((this.coverPaths.get(lesson.id) ?? '').length > 0) {
        continue;
      }
      try {
        const path: string = await GrammarBookService.ensureCover(context, lesson);
        if (path.length > 0) {
          this.coverPaths.set(lesson.id, path);
          changed = true;
        }
      } catch (error) {
        // Cover download is optional.
      }
    }
    if (changed) {
      this.localStateVersion += 1;
      this.reloadShelfSources();
    }
  }

  private coverPath(lessonId: string): string {
    return this.localStateVersion >= 0 ? (this.coverPaths.get(lessonId) ?? '') : '';
  }

  private lessonsForCategory(category: string): GrammarWork[] {
    const matched: GrammarWork[] = [];
    for (let index: number = 0; index < this.lessons.length; index++) {
      if (this.lessons[index].level === category) {
        matched.push(this.lessons[index]);
      }
    }
    return matched;
  }

  private visibleLessonCategories(): string[] {
    const visible: string[] = [];
    for (let index: number = 0; index < this.lessonCategories.length; index++) {
      const category: string = this.lessonCategories[index];
      if (this.shelfSource(category).totalCount() > 0) {
        visible.push(category);
      }
    }
    return visible;
  }

  private isLessonDownloaded(lesson: GrammarWork): boolean {
    return this.localStateVersion >= 0 && this.downloadedLessonIds.has(lesson.id);
  }

  private isLessonSelected(lesson: GrammarWork): boolean {
    return this.grammarId.length > 0 && this.grammarId === lesson.id;
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private onGrammarOpenChange(): void {
    if (!this.grammarOpen) {
      void this.refreshLocalState(this.hostContext());
    }
  }

  private shelfSource(category: string): ContentShelfDataSource<GrammarWork> {
    let source: ContentShelfDataSource<GrammarWork> | undefined = this.shelfSources.get(category);
    if (source === undefined) {
      source = new ContentShelfDataSource<GrammarWork>();
      this.shelfSources.set(category, source);
    }
    return source;
  }

  private resetShelfSources(): void {
    for (let index: number = 0; index < this.lessonCategories.length; index++) {
      const category: string = this.lessonCategories[index];
      this.shelfSource(category).reset(this.lessonsForCategory(category));
    }
  }

  private reloadShelfSources(): void {
    for (let index: number = 0; index < this.lessonCategories.length; index++) {
      this.shelfSource(this.lessonCategories[index]).reload();
    }
  }

  private selectBasicsTab(index: number): void {
    if (index < 0 || index > 1 || this.basicsTabIndex === index) {
      return;
    }
    this.basicsTabIndex = index;
    this.onTabChange(index);
  }

  private openLesson(lesson: GrammarWork): void {
    this.onOpenGrammar(lesson);
  }

  @Builder
  private basicsTabSelector() {
    Row() {
      TabSegmentButtonV2({
        items: this.basicsTabItems,
        selectedIndex: this.basicsTabIndex,
        $selectedIndex: (index: number) => this.selectBasicsTab(index),
        backgroundSystemMaterial: new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN
        })
      })
    }
    .width('100%')
    .height(60)
    .padding({ left: 18, right: 18, bottom: 8 })
  }

  build() {
    Column() {
      PageChrome({
        title: '基础',
        largeTitle: false,
        bottomHeight: 60,
        scrollers: [this.grammarScroller],
        bottomContent: () => {
          this.basicsTabSelector()
        },
        pageContent: () => {
          this.basicsContent()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private basicsContent() {
    if (this.basicsTabIndex === 0) {
      KanaPage({
        journey: this.journey,
        initialKanaKey: this.initialKanaKey,
        embedded: true,
        onScrollerReady: this.onScrollerReady,
        onFloatingBarCompactChange: this.onFloatingBarCompactChange,
        onAsk: this.onAsk,
        onKanaChange: this.onKanaChange
      })
    } else {
      this.grammarShelf()
    }
  }

  @Builder
  private grammarShelf() {
    if (this.lessonsLoading && this.lessons.length === 0) {
      Column({ space: 8 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('app.color.ink'))
        Text('正在拉取文法课…')
          .fontSize(15)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: FLOATING_TAB_CONTENT_INSET })
    } else if (this.loadError.length > 0 && this.lessons.length === 0) {
      Text(this.loadError)
        .width('100%')
        .height('100%')
        .fontSize(15)
        .fontColor($r('app.color.danger'))
        .textAlign(TextAlign.Center)
        .padding(28)
    } else {
      List({ space: 8, scroller: this.grammarScroller }) {
        ForEach(this.visibleLessonCategories(), (category: string) => {
          ListItem() {
            this.lessonShelf(category)
          }
        }, (category: string) => category)
        ListItem() {
          Column()
            .height(FLOATING_TAB_CONTENT_INSET)
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .clip(false)
      .onDidScroll((_scrollOffset: number, _scrollState: ScrollState) =>
        this.grammarFloatingBarTracker.update(this.grammarScroller, this.onFloatingBarCompactChange))
    }
  }

  @Builder
  private lessonShelf(category: string) {
    Column() {
      ContentShelf({
        title: category,
        meta: `${this.shelfSource(category).totalCount()} 课`
      })
      List({ space: 10 }) {
        LazyForEach(this.shelfSource(category), (lesson: GrammarWork) => {
          ListItem() {
            Column() {
              CoverCard({
                artwork: $r('app.media.journey_grammar'),
                artworkPath: this.coverPath(lesson.id),
                title: lesson.titleJa,
                actionIcon: $r('sys.symbol.book_pages_fill'),
                selected: this.isLessonSelected(lesson),
                cardWidth: SHELF_COVER_WIDTH,
                cardHeight: SHELF_COVER_HEIGHT,
                coverOnly: true,
                compact: true,
                downloaded: this.isLessonDownloaded(lesson),
                onOpen: () => this.openLesson(lesson)
              })
            }
            .width(SHELF_COVER_WIDTH)
            .height(SHELF_COVER_HEIGHT)
          }
        }, (lesson: GrammarWork) => lesson.id)
      }
      .listDirection(Axis.Horizontal)
      .width('100%')
      .height(SHELF_COVER_HEIGHT)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
