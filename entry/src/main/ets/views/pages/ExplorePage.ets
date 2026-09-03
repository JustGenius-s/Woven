import { common } from '@kit.AbilityKit';
import { SegmentButtonV2Items, TabSegmentButtonV2, uiMaterial } from '@kit.ArkUI';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import {
  LearningCatalog,
  MusicTrack,
  PracticeScenario,
  ReadingWork
} from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { ContentRepository } from '../../services/ContentRepository';
import { FloatingBarScrollTracker } from '../components/FloatingBarScrollTracker';
import { CoverCard } from '../components/CoverCard';
import { PageChrome } from '../components/PageChrome';

@Component
export struct ExplorePage {
  @Prop selectedTab: number = 0;
  @Prop musicIndex: number = -1;
  @Prop readingIndex: number = -1;
  @Prop scenarioIndex: number = -1;
  apiKeyConfigured: boolean = false;
  onScrollerReady: (scroller: Scroller) => void = (scroller: Scroller) => {};
  onFloatingBarCompactChange: (compact: boolean) => void = (compact: boolean) => {};
  onTabChange: (index: number) => void = (index: number) => {};
  onOpenMusic: (track: MusicTrack, index: number) => void =
    (track: MusicTrack, index: number) => {};
  onOpenReading: (reading: ReadingWork, index: number) => void =
    (reading: ReadingWork, index: number) => {};
  onScenarioChange: (index: number) => void = (index: number) => {};
  onStartScenario: (scenario: PracticeScenario) => void = (scenario: PracticeScenario) => {};
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};

  @State private catalog: LearningCatalog | undefined = undefined;
  @State private musicTracks: MusicTrack[] = [];
  @State private readingWorks: ReadingWork[] = [];
  @State private loadError: string = '';
  @State private pageWidth: number = 360;
  @State private exploreTabIndex: number = 0;
  private exploreTabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '音乐' },
    { text: '阅读' },
    { text: '场景' }
  ]);
  private musicScroller: Scroller = new Scroller();
  private readingScroller: Scroller = new Scroller();
  private scenarioScroller: Scroller = new Scroller();
  private musicFloatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('explore-music');
  private readingFloatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('explore-reading');
  private scenarioFloatingBarTracker: FloatingBarScrollTracker = new FloatingBarScrollTracker('explore-scenario');

  aboutToAppear(): void {
    this.onScrollerReady(this.musicScroller);
    this.onScrollerReady(this.readingScroller);
    this.onScrollerReady(this.scenarioScroller);
    this.exploreTabIndex = this.selectedTab;
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.catalog = ContentRepository.loadCatalog(context);
      this.musicTracks = ContentRepository.loadMusicTracks(context);
      this.readingWorks = ContentRepository.loadReadingWorks(context);
      this.loadError = '';
    } catch (error) {
      this.catalog = undefined;
      this.musicTracks = [];
      this.readingWorks = [];
      this.loadError = '探索内容没有正确载入';
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

  private readingCoverRatio(readingId: string): number {
    if (readingId === 'tadoku-40280') {
      return 1259 / 1786;
    }
    return 1;
  }

  private updatePageWidth(width: Length): void {
    const next: number = typeof width === 'number' ? width : Number.parseFloat(width as string);
    if (!Number.isNaN(next) && next > 0) {
      this.pageWidth = next;
    }
  }

  private musicArtwork(trackId: string): Resource {
    switch (trackId) {
      case 'morning-train':
        return $r('app.media.music_morning_train');
      case 'rain-cafe':
        return $r('app.media.music_rain_cafe');
      case 'small-trip':
        return $r('app.media.music_small_trip');
      case 'seaside-letter':
        return $r('app.media.music_seaside_letter');
      default:
        return $r('app.media.music_look_at_stars');
    }
  }

  private readingArtwork(readingId: string): Resource {
    switch (readingId) {
      case 'spiders-thread':
        return $r('app.media.reading_spiders_thread');
      case 'i-am-a-cat':
        return $r('app.media.reading_i_am_a_cat');
      case 'many-orders':
        return $r('app.media.reading_many_orders');
      case 'gon-fox':
        return $r('app.media.reading_gon_fox');
      case 'tadoku-40280':
        return $r('app.media.reading_two_frogs');
      default:
        return $r('app.media.reading_run_melos');
    }
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

  private openMusic(index: number): void {
    if (index < 0 || index >= this.musicTracks.length) {
      return;
    }
    this.onOpenMusic(this.musicTracks[index], index);
  }

  private openReading(index: number): void {
    if (index < 0 || index >= this.readingWorks.length) {
      return;
    }
    this.onOpenReading(this.readingWorks[index], index);
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
        bottomHeight: 60,
        scrollers: [this.musicScroller, this.readingScroller, this.scenarioScroller],
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
    .onAreaChange((oldArea: Area, newArea: Area) => this.updatePageWidth(newArea.width))
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
      this.musicPage()
    } else if (this.activeExploreTab() === 1) {
      this.readingPage()
    } else {
      this.scenarioPage()
    }
  }

  @Builder
  private musicPage() {
    Scroll(this.musicScroller) {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(this.musicTracks, (track: MusicTrack, index: number) => {
          Column() {
            this.musicCard(track, index)
          }
          .width(this.cardFlowWidth())
          .margin({ right: this.cardRightMargin(index), bottom: 14 })
        }, (track: MusicTrack) => track.id)
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
      this.musicFloatingBarTracker.update(this.musicScroller, this.onFloatingBarCompactChange))
  }

  @Builder
  private musicCard(track: MusicTrack, index: number) {
    CoverCard({
      artwork: this.musicArtwork(track.id),
      badge: track.level,
      meta: `${track.lines.length} 句`,
      title: track.title,
      subtitle: `${track.chineseTitle} · ${track.artist}`,
      footer: track.focus,
      actionIcon: $r('sys.symbol.music_note_circle_fill'),
      selected: this.musicIndex === index,
      onOpen: () => this.openMusic(index)
    })
  }

  @Builder
  private readingPage() {
    Scroll(this.readingScroller) {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(this.readingWorks, (reading: ReadingWork, index: number) => {
          Column() {
            this.readingCard(reading, index)
          }
          .width(this.cardFlowWidth())
          .margin({ right: this.cardRightMargin(index), bottom: 14 })
        }, (reading: ReadingWork) => reading.id)
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
      this.readingFloatingBarTracker.update(this.readingScroller, this.onFloatingBarCompactChange))
  }

  @Builder
  private readingCard(reading: ReadingWork, index: number) {
    CoverCard({
      artwork: this.readingArtwork(reading.id),
      badge: reading.genre,
      meta: reading.level,
      title: reading.title,
      subtitle: `${reading.author} · ${reading.titleReading}`,
      caption: reading.summary,
      footer: reading.format === 'pdf' ?
        `${reading.passages.length} 页 · 绘本${reading.audioFile ? ' · 朗读' : ''}` :
        (reading.complete ? `${reading.passages.length} 阅读页 · 全文` : `${reading.passages.length} 段节选`),
      actionIcon: $r('sys.symbol.book_pages_fill'),
      selected: this.readingIndex === index,
      coverRatio: this.readingCoverRatio(reading.id),
      onOpen: () => this.openReading(index)
    })
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
