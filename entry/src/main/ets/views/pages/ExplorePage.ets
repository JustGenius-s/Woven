import { common } from '@kit.AbilityKit';
import {
  BorderRadiusMode,
  ItemRestriction,
  LengthMetrics,
  SegmentButton,
  SegmentButtonOptions,
  SegmentButtonTextItem
} from '@kit.ArkUI';
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
import { planeLightEffect } from '../components/ImmersiveCanvas';
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
  @State private exploreTabIndexes: number[] = [0];
  @State private exploreTabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [
      { text: '音乐' },
      { text: '阅读' },
      { text: '场景' }
    ] as ItemRestriction<SegmentButtonTextItem>,
    fontColor: $r('app.color.ink_muted'),
    selectedFontColor: $r('app.color.ink'),
    fontSize: 15,
    selectedFontSize: 15,
    fontWeight: FontWeight.Regular,
    selectedFontWeight: FontWeight.Medium,
    backgroundColor: $r('app.color.surface_raised'),
    selectedBackgroundColor: $r('app.color.accent_soft'),
    borderRadiusMode: BorderRadiusMode.CUSTOM,
    backgroundBorderRadius: LengthMetrics.vp(22),
    itemBorderRadius: LengthMetrics.vp(19),
    buttonPadding: 2,
    textPadding: { left: 8, right: 8, top: 8, bottom: 8 }
  });
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
    this.exploreTabIndexes = [this.selectedTab];
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
    if (index < 0 || index > 2 || this.exploreTabIndexes[0] === index) {
      return;
    }
    this.exploreTabIndexes = [index];
    this.onTabChange(index);
  }

  private activeExploreTab(): number {
    return this.exploreTabIndexes.length > 0 ? this.exploreTabIndexes[0] : this.selectedTab;
  }

  @Builder
  private exploreTabSelector() {
    Row() {
      SegmentButton({
        options: this.exploreTabOptions,
        selectedIndexes: this.exploreTabIndexes,
        onItemClicked: (index: number) => this.selectExploreTab(index)
      })
        .layoutWeight(1)
        .height(44)
        .clip(true)
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
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.musicArtwork(track.id))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0.24], ['#4D17181A', 0.56], ['#E617181A', 1]]
        })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Text(track.level)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.immersive_light'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(13)
            .backgroundColor('#6617181A')
          Blank()
          Text(`${track.lines.length} 句`)
            .fontSize(12)
            .fontColor($r('app.color.immersive_light'))
        }
        Blank()
        Text(track.title)
          .width('100%')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.immersive_light'))
          .maxLines(1)
        Text(`${track.chineseTitle} · ${track.artist}`)
          .width('100%')
          .fontSize(13)
          .fontColor('#D9F7F8FA')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Row() {
          Text(track.focus)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor('#D9F7F8FA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.music_note_circle_fill'))
              .fontSize(27)
              .fontColor([$r('app.color.ink')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.immersive_light'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 14 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
    }
    .width('100%')
    .height(304)
    .borderRadius(28)
    .clip(true)
    .border({ width: this.musicIndex === index ? 1.5 : 0.5,
      color: this.musicIndex === index ? $r('app.color.accent') : $r('app.color.line') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${track.title}，${track.chineseTitle}，${track.level}`)
    .onClick(() => this.openMusic(index))
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
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.readingArtwork(reading.id))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0.28], ['#4217181A', 0.58], ['#E617181A', 1]]
        })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Text(reading.genre)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.immersive_light'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(13)
            .backgroundColor('#6617181A')
          Blank()
          Text(reading.level)
            .fontSize(12)
            .fontColor('#D9F7F8FA')
        }
        Blank()
        Text(reading.title)
          .width('100%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.immersive_light'))
          .maxLines(1)
        Text(`${reading.author} · ${reading.titleReading}`)
          .width('100%')
          .fontSize(13)
          .fontColor('#D9F7F8FA')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Text(reading.summary)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#CCF7F8FA')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Row() {
          Text(reading.complete ? `${reading.passages.length} 阅读页 · 全文` : `${reading.passages.length} 段节选`)
            .fontSize(12)
            .fontColor('#D9F7F8FA')
          Blank()
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.book_pages_fill'))
              .fontSize(24)
              .fontColor([$r('app.color.ink')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.immersive_light'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
    }
    .width('100%')
    .height(284)
    .borderRadius(28)
    .clip(true)
    .border({ width: this.readingIndex === index ? 1.5 : 0.5,
      color: this.readingIndex === index ? $r('app.color.accent') : $r('app.color.line') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${reading.title}，${reading.author}，${reading.level}`)
    .onClick(() => this.openReading(index))
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
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.scenarioArtwork(scenario.id))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0.22], ['#4D17181A', 0.52], ['#ED17181A', 1]]
        })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Text(scenario.level)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.immersive_light'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(13)
            .backgroundColor('#6617181A')
          Blank()
          Text(scenario.setting)
            .fontSize(11)
            .fontColor('#D9F7F8FA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Blank()
        Text(scenario.title)
          .width('100%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.immersive_light'))
          .maxLines(1)
        Text(`${scenario.learnerRole} × ${scenario.aiRole}`)
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#D9F7F8FA')
          .margin({ top: 5 })
        Text(scenario.goal)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#D9F7F8FA')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 7 })
        Row() {
          if (this.scenarioIndex === index) {
            Text('上次进行')
              .fontSize(11)
              .fontColor($r('app.color.immersive_light'))
          }
          Blank()
          Button('开始', { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
            .controlSize(ControlSize.NORMAL)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.immersive_light'))
            .enabled(this.apiKeyConfigured)
            .onClick(() => this.startScenario(scenario, index))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 13 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
    }
    .width('100%')
    .height(304)
    .borderRadius(28)
    .clip(true)
    .border({ width: this.scenarioIndex === index ? 1.5 : 0.5,
      color: this.scenarioIndex === index ? $r('app.color.accent') : $r('app.color.line') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${scenario.title}，${scenario.setting}，${scenario.level}`)
  }

}
