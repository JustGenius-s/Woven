import { common } from '@kit.AbilityKit';
import { promptAction, SegmentButtonV2Items, TabSegmentButtonV2, uiMaterial } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import {
  LearningCatalog,
  PracticeScenario,
  ReadingWork
} from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { VideoItem, videoSourceLabel } from '../../model/VideoModels';
import { ContentRepository } from '../../services/ContentRepository';
import { ContentShelfDataSource } from '../../services/ContentShelfDataSource';
import { ReadingBookService } from '../../services/ReadingBookService';
import { VideoLibraryStore } from '../../services/VideoLibraryStore';
import { FloatingBarScrollTracker } from '../components/FloatingBarScrollTracker';
import {
  ContentShelf,
  SHELF_COVER_HEIGHT,
  SHELF_COVER_WIDTH,
  SHELF_VIDEO_HEIGHT,
  SHELF_VIDEO_WIDTH
} from '../components/ContentShelf';
import { CoverCard } from '../components/CoverCard';
import { PageChrome } from '../components/PageChrome';

@Component
export struct ExplorePage {
  @Prop selectedTab: number = 0;
  @Prop videoId: string = '';
  @Prop readingIndex: number = -1;
  @Prop @Watch('onReadingOpenChange') readingOpen: boolean = false;
  @Prop scenarioIndex: number = -1;
  apiKeyConfigured: boolean = false;
  onScrollerReady: (scroller: Scroller) => void = (scroller: Scroller) => {};
  onFloatingBarCompactChange: (compact: boolean) => void = (compact: boolean) => {};
  onTabChange: (index: number) => void = (index: number) => {};
  onOpenVideo: (video: VideoItem) => void = (video: VideoItem) => {};
  onOpenReading: (reading: ReadingWork, index: number) => void =
    (reading: ReadingWork, index: number) => {};
  onScenarioChange: (index: number) => void = (index: number) => {};
  onStartScenario: (scenario: PracticeScenario) => void = (scenario: PracticeScenario) => {};
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};

  @State private catalog: LearningCatalog | undefined = undefined;
  @State private videos: VideoItem[] = [];
  @State private readingWorks: ReadingWork[] = [];
  @State private localStateVersion: number = 0;
  @State private loadError: string = '';
  @State private readingsLoading: boolean = true;
  @State private pageWidth: number = 360;
  @State private exploreTabIndex: number = 0;
  @State private urlSheetOpen: boolean = false;
  @State private urlDraft: string = '';
  @State private titleDraft: string = '';
  private exploreTabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '视频' },
    { text: '阅读' },
    { text: '场景' }
  ]);
  private videoScroller: Scroller = new Scroller();
  private readingScroller: Scroller = new Scroller();
  private scenarioScroller: Scroller = new Scroller();
  private videoFloatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('explore-video');
  private readingFloatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('explore-reading');
  private scenarioFloatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('explore-scenario');
  private coverPaths: Map<string, string> = new Map();
  private downloadedReadingIds: Set<string> = new Set();
  private shelfSources: Map<string, ContentShelfDataSource<ReadingWork>> = new Map();
  private localStateGeneration: number = 0;
  private readonly readingCategories: string[] =
    ['L0入门', 'L0', 'L1', 'L2', 'L3', 'L4', 'L5'];
  private readonly videoGroupOrder: string[] =
    ['哔哩哔哩', 'YouTube', '网络视频', '网页视频', '本地视频'];

  aboutToAppear(): void {
    this.onScrollerReady(this.videoScroller);
    this.onScrollerReady(this.readingScroller);
    this.onScrollerReady(this.scenarioScroller);
    this.exploreTabIndex = this.selectedTab;
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.catalog = ContentRepository.loadCatalog(context);
      this.videos = VideoLibraryStore.load(context);
      this.loadError = '';
      void this.initializeReadings(context);
    } catch (error) {
      this.catalog = undefined;
      this.videos = [];
      this.readingWorks = [];
      this.loadError = '探索内容没有正确载入';
    }
  }

  private async initializeReadings(context: common.Context): Promise<void> {
    this.readingsLoading = true;
    this.readingWorks = await ContentRepository.loadReadingWorksAsync(context);
    this.resetShelfSources();
    void this.refreshLocalState(context);
    await this.refreshReadings(context);
  }

  private async refreshReadings(context: common.Context): Promise<void> {
    this.readingsLoading = this.readingWorks.length === 0;
    try {
      this.readingWorks = await ContentRepository.prefetchReadings(context);
      this.resetShelfSources();
      await this.refreshLocalState(context);
      void this.downloadCovers(context);
      if (this.readingWorks.length > 0) {
        this.loadError = '';
      }
    } catch (error) {
      if (this.readingWorks.length === 0) {
        const detail: string = error instanceof Error ? error.message : '';
        this.loadError = detail.length > 0 ? `阅读书目加载失败：${detail}` : '阅读书目加载失败';
      }
    } finally {
      this.readingsLoading = false;
    }
  }

  private cardFlowWidth(): Length {
    if (this.pageWidth < 700) {
      return '100%';
    }
    return Math.max(280, (this.pageWidth - 50) / 2);
  }

  private cardRightMargin(index: number): number {
    return this.pageWidth >= 700 && index % 2 === 0 ? 14 : 0;
  }

  private async refreshLocalState(context: common.Context): Promise<void> {
    const generation: number = ++this.localStateGeneration;
    const readings: ReadingWork[] = this.readingWorks.slice();
    const nextCovers: Map<string, string> = new Map();
    const nextDownloaded: Set<string> = new Set();
    for (let index: number = 0; index < readings.length; index++) {
      const reading: ReadingWork = readings[index];
      let cover: string = await ReadingBookService.coverReadyAsync(context, reading);
      const relative: string | undefined = reading.coverFile;
      if (cover.length === 0 && relative !== undefined && relative.length > 0) {
        try {
          cover = await ReadingBookService.materializeCoverAsync(context, reading.id, relative);
        } catch (error) {
          // Official cover is optional; the card falls back to a plate image.
        }
      }
      if (cover.length > 0) {
        nextCovers.set(reading.id, cover);
      }
      if (await ReadingBookService.isBookReadyAsync(context, reading)) {
        nextDownloaded.add(reading.id);
      }
    }
    if (generation !== this.localStateGeneration) {
      return;
    }
    this.coverPaths = nextCovers;
    this.downloadedReadingIds = nextDownloaded;
    this.localStateVersion += 1;
    this.reloadShelfSources();
  }

  private async downloadCovers(context: common.Context): Promise<void> {
    let changed: boolean = false;
    for (let index: number = 0; index < this.readingWorks.length; index++) {
      const reading: ReadingWork = this.readingWorks[index];
      if (reading.coverKey === undefined || reading.coverKey.length === 0) {
        continue;
      }
      if ((this.coverPaths.get(reading.id) ?? '').length > 0) {
        continue;
      }
      try {
        const path: string = await ReadingBookService.ensureCover(context, reading);
        if (path.length > 0) {
          this.coverPaths.set(reading.id, path);
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

  private coverPath(readingId: string): string {
    return this.localStateVersion >= 0 ? (this.coverPaths.get(readingId) ?? '') : '';
  }

  private matchesCategory(reading: ReadingWork, category: string): boolean {
    if (category === '全部') {
      return true;
    }
    return reading.level === category || reading.category === category;
  }

  private readingsForCategory(category: string): ReadingWork[] {
    const matched: ReadingWork[] = [];
    for (let index: number = 0; index < this.readingWorks.length; index++) {
      const reading: ReadingWork = this.readingWorks[index];
      if (this.matchesCategory(reading, category)) {
        matched.push(reading);
      }
    }
    return matched;
  }

  private visibleReadingCategories(): string[] {
    const visible: string[] = [];
    for (let index: number = 0; index < this.readingCategories.length; index++) {
      const category: string = this.readingCategories[index];
      if (this.shelfSource(category).totalCount() > 0) {
        visible.push(category);
      }
    }
    return visible;
  }

  private videosForGroup(label: string): VideoItem[] {
    const matched: VideoItem[] = [];
    for (let index: number = 0; index < this.videos.length; index++) {
      if (videoSourceLabel(this.videos[index]) === label) {
        matched.push(this.videos[index]);
      }
    }
    return matched;
  }

  private visibleVideoGroups(): string[] {
    const visible: string[] = [];
    for (let index: number = 0; index < this.videoGroupOrder.length; index++) {
      const label: string = this.videoGroupOrder[index];
      if (this.videosForGroup(label).length > 0) {
        visible.push(label);
      }
    }
    return visible;
  }

  private isReadingSelected(reading: ReadingWork): boolean {
    if (this.readingIndex < 0 || this.readingIndex >= this.readingWorks.length) {
      return false;
    }
    return this.readingWorks[this.readingIndex].id === reading.id;
  }

  private updatePageWidth(width: Length): void {
    const next: number = typeof width === 'number' ? width : Number.parseFloat(width as string);
    if (!Number.isNaN(next) && next > 0) {
      this.pageWidth = next;
    }
  }

  private readingArtwork(): Resource {
    return $r('app.media.reading_default');
  }

  private scenarioArtwork(scenarioId: string): Resource {
    switch (scenarioId) {
      case 'cafe':
        return $r('app.media.scenario_cafe');
      case 'directions':
        return $r('app.media.scenario_directions');
      case 'restaurant':
        return $r('app.media.scenario_restaurant');
      case 'small-talk':
        return $r('app.media.scenario_small_talk');
      default:
        return $r('app.media.scenario_opinion');
    }
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private openAddMenu(): void {
    this.getUIContext().getPromptAction().showActionMenu({
      title: '添加视频',
      buttons: [
        { text: '添加网络视频', color: '#2E5BF4' },
        { text: '导入本地视频', color: '#6B7078' }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index === 0) {
        this.openUrlSheet();
      } else if (result.index === 1) {
        void this.importLocalVideo();
      }
    }).catch(() => {
      // The user dismissed the menu.
    });
  }

  private openUrlSheet(): void {
    this.urlDraft = '';
    this.titleDraft = '';
    this.urlSheetOpen = true;
  }

  private confirmUrl(): void {
    try {
      const item: VideoItem = VideoLibraryStore.addUrl(this.hostContext(), this.urlDraft, this.titleDraft);
      this.videos = VideoLibraryStore.load(this.hostContext());
      this.urlSheetOpen = false;
      this.onOpenVideo(item);
    } catch (error) {
      const detail: string = error instanceof Error ? error.message : '无法添加视频';
      showImmersiveNotice(this.getUIContext(), '还不能添加', detail);
    }
  }

  private async importLocalVideo(): Promise<void> {
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.hostContext());
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.mp4,.mkv,.mov,.webm,.m4v'];
      const uris: Array<string> = await documentPicker.select(options);
      if (uris.length === 0) {
        return;
      }
      const item: VideoItem = await VideoLibraryStore.importFromUri(this.hostContext(), uris[0], uris[0]);
      this.videos = VideoLibraryStore.load(this.hostContext());
      this.onOpenVideo(item);
    } catch (error) {
      const detail: string = error instanceof Error ? error.message : '无法导入视频';
      showImmersiveNotice(this.getUIContext(), '导入失败', detail);
    }
  }

  private removeVideo(videoId: string): void {
    this.videos = VideoLibraryStore.remove(this.hostContext(), videoId);
  }

  private formatDuration(durationMs: number): string {
    if (durationMs <= 0) {
      return '';
    }
    const totalSeconds: number = Math.floor(durationMs / 1000);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private onReadingOpenChange(): void {
    if (!this.readingOpen) {
      void this.refreshLocalState(this.hostContext());
    }
  }

  private isReadingDownloaded(reading: ReadingWork): boolean {
    return this.localStateVersion >= 0 && this.downloadedReadingIds.has(reading.id);
  }

  private shelfSource(category: string): ContentShelfDataSource<ReadingWork> {
    let source: ContentShelfDataSource<ReadingWork> | undefined = this.shelfSources.get(category);
    if (source === undefined) {
      source = new ContentShelfDataSource<ReadingWork>();
      this.shelfSources.set(category, source);
    }
    return source;
  }

  private resetShelfSources(): void {
    for (let index: number = 0; index < this.readingCategories.length; index++) {
      const category: string = this.readingCategories[index];
      this.shelfSource(category).reset(this.readingsForCategory(category));
    }
  }

  private reloadShelfSources(): void {
    for (let index: number = 0; index < this.readingCategories.length; index++) {
      this.shelfSource(this.readingCategories[index]).reload();
    }
  }

  private openReading(reading: ReadingWork): void {
    let index: number = -1;
    for (let cursor: number = 0; cursor < this.readingWorks.length; cursor++) {
      if (this.readingWorks[cursor].id === reading.id) {
        index = cursor;
        break;
      }
    }
    if (index < 0) {
      return;
    }
    this.onOpenReading(reading, index);
  }

  private startScenario(scenario: PracticeScenario, index: number): void {
    if (!this.apiKeyConfigured) {
      return;
    }
    this.onScenarioChange(index);
    this.onStartScenario(scenario);
  }

  private selectExploreTab(index: number): void {
    if (index < 0 || index > 2 || this.exploreTabIndex === index) {
      return;
    }
    this.exploreTabIndex = index;
    this.onTabChange(index);
  }

  private activeExploreTab(): number {
    return this.exploreTabIndex;
  }

  @Builder
  private exploreTabSelector() {
    Row() {
      TabSegmentButtonV2({
        items: this.exploreTabItems,
        selectedIndex: this.exploreTabIndex,
        $selectedIndex: (index: number) => this.selectExploreTab(index),
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
        title: '探索',
        largeTitle: false,
        bottomHeight: 60,
        showMenuAction: this.activeExploreTab() === 0,
        menuIcon: $r('sys.symbol.plus'),
        menuLabel: '添加视频',
        onMenu: () => this.openAddMenu(),
        scrollers: [this.videoScroller, this.readingScroller, this.scenarioScroller],
        bottomContent: () => {
          this.exploreTabSelector()
        },
        pageContent: () => {
          this.exploreContent()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .bindSheet($$this.urlSheetOpen, this.urlSheet(), {
      height: SheetSize.FIT_CONTENT,
      preferType: SheetType.BOTTOM,
      title: { title: '添加网络视频' },
      dragBar: true,
      showClose: true,
      blurStyle: BlurStyle.COMPONENT_REGULAR,
      backgroundColor: $r('app.color.surface_raised'),
      maskColor: '#52000000',
      onDisappear: () => this.urlSheetOpen = false
    })
    .onAreaChange((oldArea: Area, newArea: Area) => this.updatePageWidth(newArea.width))
  }

  @Builder
  private urlSheet() {
    Column({ space: 14 }) {
      TextInput({ text: this.urlDraft, placeholder: 'https://' })
        .width('100%')
        .height(48)
        .onChange((value: string) => this.urlDraft = value)
      TextInput({ text: this.titleDraft, placeholder: '标题（可选）' })
        .width('100%')
        .height(48)
        .onChange((value: string) => this.titleDraft = value)
      Button('添加并播放', { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
        .width('100%')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .enabled(VideoLibraryStore.normalizedUrl(this.urlDraft).length > 0)
        .onClick(() => this.confirmUrl())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 28 })
  }

  @Builder
  private exploreContent() {
    if (this.loadError.length > 0) {
      Text(this.loadError)
        .width('100%')
        .height('100%')
        .fontSize(15)
        .fontColor($r('app.color.danger'))
        .textAlign(TextAlign.Center)
        .padding(28)
    } else if (this.activeExploreTab() === 0) {
      this.videoPage()
    } else if (this.activeExploreTab() === 1) {
      this.readingPage()
    } else {
      this.scenarioPage()
    }
  }

  @Builder
  private videoPage() {
    if (this.videos.length === 0) {
      Column({ space: 8 }) {
        Text('还没有视频')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
        Text('点右上角添加网络链接，或导入手机里的视频。')
          .fontSize(14)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 28, right: 28, bottom: FLOATING_TAB_CONTENT_INSET })
    } else {
      List({ space: 8, scroller: this.videoScroller }) {
        ForEach(this.visibleVideoGroups(), (label: string) => {
          ListItem() {
            this.videoShelf(label)
          }
        }, (label: string) => label)
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
        this.videoFloatingBarTracker.update(this.videoScroller, this.onFloatingBarCompactChange))
    }
  }

  @Builder
  private videoShelf(label: string) {
    Column() {
      ContentShelf({
        title: label,
        meta: `${this.videosForGroup(label).length} 个`
      })
      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.videosForGroup(label), (video: VideoItem) => {
            this.videoCard(video)
          }, (video: VideoItem) => video.id)
        }
        .height(SHELF_VIDEO_HEIGHT)
        .alignItems(VerticalAlign.Top)
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(SHELF_VIDEO_HEIGHT)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private videoCard(video: VideoItem) {
    Column({ space: 6 }) {
      Row() {
        if (this.formatDuration(video.durationMs).length > 0) {
          Text(this.formatDuration(video.durationMs))
            .fontSize(11)
            .fontColor('#D9F7F8FA')
        }
        Blank()
        SymbolGlyph($r('sys.symbol.play_circle_fill'))
          .fontSize(18)
          .fontColor([$r('app.color.immersive_light')])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Blank()

      Text(video.title)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.immersive_light'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(SHELF_VIDEO_WIDTH)
    .height(SHELF_VIDEO_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(16)
    .linearGradient({
      angle: 135,
      colors: [['#FF2A3340', 0], ['#FF17181A', 1]]
    })
    .border({
      width: this.videoId === video.id ? 1.5 : 0.5,
      color: this.videoId === video.id ? $r('app.color.accent') : $r('app.color.line')
    })
    .clip(true)
    .accessibilityText(video.title)
    .onClick(() => this.onOpenVideo(video))
    .bindContextMenu(this.videoCardMenu(video), ResponseType.LongPress)
  }

  @Builder
  private videoCardMenu(video: VideoItem) {
    Menu() {
      MenuItem({ content: '删除' })
        .onChange(() => this.removeVideo(video.id))
    }
  }

  @Builder
  private readingPage() {
    if (this.readingsLoading && this.readingWorks.length === 0) {
      Column({ space: 8 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('app.color.ink'))
        Text('正在拉取绘本…')
          .fontSize(15)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: FLOATING_TAB_CONTENT_INSET })
    } else {
      List({ space: 8, scroller: this.readingScroller }) {
        ForEach(this.visibleReadingCategories(), (category: string) => {
          ListItem() {
            this.readingShelf(category)
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
        this.readingFloatingBarTracker.update(this.readingScroller, this.onFloatingBarCompactChange))
    }
  }

  @Builder
  private readingShelf(category: string) {
    Column() {
      ContentShelf({
        title: category,
        meta: `${this.shelfSource(category).totalCount()} 本`
      })
      List({ space: 10 }) {
        LazyForEach(this.shelfSource(category), (reading: ReadingWork) => {
          ListItem() {
            Column() {
              CoverCard({
                artwork: this.readingArtwork(),
                artworkPath: this.coverPath(reading.id),
                title: reading.title,
                actionIcon: $r('sys.symbol.book_pages_fill'),
                selected: this.isReadingSelected(reading),
                cardWidth: SHELF_COVER_WIDTH,
                cardHeight: SHELF_COVER_HEIGHT,
                coverOnly: true,
                compact: true,
                downloaded: this.isReadingDownloaded(reading),
                onOpen: () => this.openReading(reading)
              })
            }
            .width(SHELF_COVER_WIDTH)
            .height(SHELF_COVER_HEIGHT)
          }
        }, (reading: ReadingWork) => reading.id)
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

  @Builder
  private scenarioPage() {
    Scroll(this.scenarioScroller) {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(this.catalog?.practiceScenarios ?? [], (scenario: PracticeScenario, index: number) => {
          Column() {
            this.scenarioCard(scenario, index)
          }
          .width(this.cardFlowWidth())
          .margin({ right: this.cardRightMargin(index), bottom: 14 })
        }, (scenario: PracticeScenario) => scenario.id)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: FLOATING_TAB_CONTENT_INSET })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .clip(false)
    .onDidScroll((_xOffset: number, _yOffset: number, _scrollState: ScrollState) =>
      this.scenarioFloatingBarTracker.update(this.scenarioScroller, this.onFloatingBarCompactChange))
  }

  @Builder
  private scenarioCard(scenario: PracticeScenario, index: number) {
    CoverCard({
      artwork: this.scenarioArtwork(scenario.id),
      badge: scenario.level,
      meta: scenario.setting,
      title: scenario.title,
      subtitle: `${scenario.learnerRole} × ${scenario.aiRole}`,
      caption: scenario.goal,
      captionLines: 2,
      footer: this.scenarioIndex === index ? '上次进行' : '',
      actionLabel: '开始',
      actionEnabled: this.apiKeyConfigured,
      selected: this.scenarioIndex === index,
      onOpen: () => this.startScenario(scenario, index)
    })
  }

}
