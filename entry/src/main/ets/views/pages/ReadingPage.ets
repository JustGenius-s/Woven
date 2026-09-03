import { common } from '@kit.AbilityKit';
import {
  BorderRadiusMode,
  ItemRestriction,
  LengthMetrics,
  SegmentButton,
  SegmentButtonOptions,
  SegmentButtonTextItem,
  window
} from '@kit.ArkUI';
import {
  ActionBarButton,
  ActionBarStyle,
  BlurStrategy,
  DividerShowType,
  HdsActionBar,
  HdsNavigation,
  HdsNavigationTitleMode,
  TitleSize
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import { systemGestureInset } from '../../common/AppTheme';
import { FLOATING_CHROME_MATERIAL, preferredImmersiveMaterial } from '../../common/ImmersiveMaterial';
import { ReadingAudioCue, ReadingAudioRect, ReadingPassage, ReadingWork } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ReadingBookService } from '../../services/ReadingBookService';
import {
  ReadingNarrationListener,
  ReadingNarrationService,
  ReadingNarrationSnapshot
} from '../../services/ReadingNarrationService';
import { ReaderPreferences, ReaderProgressSnapshot, ReaderStyleSnapshot } from '../../services/ReaderPreferences';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { PdfReadingCanvas } from '../components/PdfReadingCanvas';

const EMPTY_READING: ReadingWork = {
  id: '',
  title: '',
  titleReading: '',
  author: '',
  level: '',
  genre: '',
  summary: '',
  sourceName: '',
  sourceUrl: '',
  rights: '',
  format: '',
  pdfFile: '',
  passages: []
};

// Height HdsNavigation's MINI title bar occupies in layout. Hiding the bar
// reclaims exactly this much, so the content must compensate to avoid a jump.
const READER_TITLE_BAR_HEIGHT: number = 56;

// Keep Aozora pages on system ArkUI. PDF books use HMS PDF Kit in PdfReadingCanvas;
// Reader Kit's kitview HSP is still avoided because it is missing on simulators.
@Component
export struct ReadingPage {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  reading: ReadingWork = EMPTY_READING;
  onBack: () => void = () => {};
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};

  @State private controlsVisible: boolean = true;
  @State private panelOpen: boolean = false;
  @State private panelKind: number = 0;
  @State private currentPassageIndex: number = 0;
  @State private displayPageIndex: number = 0;
  @State private fontSize: number = 22;
  @State private lineHeight: number = 1.9;
  @State private flipMode: number = 0;
  @State private flipIndexes: number[] = [0];
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 780;
  @State private dualPage: boolean = false;
  @State private forceSinglePage: boolean = false;
  @State private pinching: boolean = false;
  @State private pdfPath: string = '';
  @State private pdfFailed: boolean = false;
  @State private pdfJumpPage: number = 0;
  @State private narrationPlaying: boolean = false;
  @State private narrationReady: boolean = false;
  @State private highlightKey: string = '';
  @State private highlightPage: number = 0;
  @State private highlightRects: ReadingAudioRect[] = [];

  private pageController: SwiperController = new SwiperController();
  private pinchStartFontSize: number = 22;
  private hasSavedStyle: boolean = false;
  private ignorePageSyncUntil: number = 0;
  private lastNarrationPage: number = -1;
  private readonly onNarrationSnapshot: ReadingNarrationListener =
    (snapshot: ReadingNarrationSnapshot) => this.handleNarrationSnapshot(snapshot);
  @State private flipOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [
      { text: '左右翻页' },
      { text: '上下翻页' }
    ] as ItemRestriction<SegmentButtonTextItem>,
    fontColor: $r('app.color.ink_muted'),
    selectedFontColor: $r('app.color.ink'),
    fontSize: 14,
    selectedFontSize: 14,
    fontWeight: FontWeight.Regular,
    selectedFontWeight: FontWeight.Medium,
    backgroundColor: $r('app.color.surface_raised'),
    selectedBackgroundColor: $r('app.color.accent_soft'),
    borderRadiusMode: BorderRadiusMode.CUSTOM,
    backgroundBorderRadius: LengthMetrics.vp(20),
    itemBorderRadius: LengthMetrics.vp(17),
    buttonPadding: 2,
    textPadding: { left: 8, right: 8, top: 8, bottom: 8 }
  });

  aboutToAppear(): void {
    const style: ReaderStyleSnapshot = ReaderPreferences.style(this.hostContext());
    this.hasSavedStyle = ReaderPreferences.hasStyle(this.hostContext());
    this.fontSize = Math.max(18, Math.min(style.fontSize, 28));
    this.lineHeight = Math.max(1.5, Math.min(style.lineHeight, 2.3));
    this.flipMode = Math.max(0, Math.min(style.flipMode, 1));
    this.flipIndexes = [this.flipMode];
    const progress: ReaderProgressSnapshot = ReaderPreferences.progress(this.hostContext(), this.reading.id);
    this.currentPassageIndex = this.safePassageIndex(progress.resourceIndex);
    this.displayPageIndex = this.currentPassageIndex;
    if (this.isPdfBook()) {
      this.openPdfBook();
    }
    if (this.hasNarration()) {
      ReadingNarrationService.subscribe(this.onNarrationSnapshot);
      void ReadingNarrationService.prepare(
        this.hostContext(), this.reading.audioFile ?? '', this.reading.audioDurationMs ?? 0);
    }
  }

  private isPdfBook(): boolean {
    return this.reading.format === 'pdf';
  }

  private openPdfBook(): void {
    const relative: string | undefined = this.reading.pdfFile;
    if (relative === undefined || relative.length === 0) {
      this.pdfFailed = true;
      return;
    }
    try {
      this.pdfPath = ReadingBookService.materializePdf(
        this.hostContext(), this.reading.id, relative);
      this.pdfJumpPage = this.currentPassageIndex;
      this.pdfFailed = false;
    } catch (error) {
      this.pdfPath = '';
      this.pdfFailed = true;
    }
  }

  private readingLength(): number {
    return this.reading.passages.length;
  }

  aboutToDisappear(): void {
    if (this.hasNarration()) {
      ReadingNarrationService.unsubscribe(this.onNarrationSnapshot);
      void ReadingNarrationService.release();
    }
  }

  private hasNarration(): boolean {
    return this.reading.audioFile !== undefined && this.reading.audioFile.length > 0 &&
      this.reading.audioCues !== undefined && this.reading.audioCues.length > 0;
  }

  private narrationCues(): ReadingAudioCue[] {
    return this.reading.audioCues ?? [];
  }

  private handleNarrationSnapshot(snapshot: ReadingNarrationSnapshot): void {
    this.narrationPlaying = snapshot.playing;
    this.narrationReady = snapshot.ready;
    if (!snapshot.playing) {
      return;
    }
    const cue: ReadingAudioCue | undefined =
      ReadingNarrationService.cueAt(this.narrationCues(), snapshot.positionMs);
    if (cue === undefined) {
      this.clearHighlight();
      return;
    }
    if (cue.page !== this.currentPassageIndex) {
      this.ignorePageSyncUntil = Date.now() + 450;
      this.currentPassageIndex = this.safePassageIndex(cue.page);
      this.displayPageIndex = this.currentPassageIndex;
      this.pdfJumpPage = this.currentPassageIndex;
      this.saveProgress();
    }
    this.lastNarrationPage = cue.page;
    this.applyCueHighlight(cue);
  }

  private applyCueHighlight(cue: ReadingAudioCue): void {
    const key: string = `${cue.page}-${cue.startMs}`;
    if (this.highlightKey === key) {
      return;
    }
    this.highlightPage = cue.page;
    this.highlightRects = cue.rects.slice();
    this.highlightKey = key;
  }

  private clearHighlight(): void {
    if (this.highlightKey.length === 0) {
      return;
    }
    this.highlightRects = [];
    this.highlightKey = '';
  }

  private async toggleNarration(): Promise<void> {
    if (!this.hasNarration()) {
      return;
    }
    if (!this.narrationReady) {
      await ReadingNarrationService.prepare(
        this.hostContext(), this.reading.audioFile ?? '', this.reading.audioDurationMs ?? 0);
    }
    if (!this.narrationPlaying) {
      const snapshot: ReadingNarrationSnapshot = ReadingNarrationService.snapshot();
      const current: ReadingAudioCue | undefined =
        ReadingNarrationService.cueAt(this.narrationCues(), snapshot.positionMs);
      if (current === undefined || current.page !== this.currentPassageIndex) {
        await this.seekNarrationToPage(this.currentPassageIndex);
      }
    }
    await ReadingNarrationService.toggle();
  }

  private async seekNarrationToPage(page: number): Promise<void> {
    const cues: ReadingAudioCue[] = this.narrationCues();
    const targetPage: number = ReadingNarrationService.nearestCuePage(cues, page);
    const cue: ReadingAudioCue | undefined = ReadingNarrationService.firstCueOnPage(cues, targetPage);
    if (cue === undefined) {
      return;
    }
    if (targetPage !== this.currentPassageIndex) {
      this.ignorePageSyncUntil = Date.now() + 450;
      this.jumpToPassage(targetPage);
    }
    await ReadingNarrationService.seek(cue.startMs);
  }

  private hostContext(): common.Context {
    return this.getUIContext().getHostContext() as common.Context;
  }

  private safePassageIndex(index: number): number {
    const total: number = this.readingLength();
    if (total === 0) {
      return 0;
    }
    return Math.max(0, Math.min(index, total - 1));
  }

  private isWideLandscape(width: number = this.viewportWidth, height: number = this.viewportHeight): boolean {
    return width >= 840 && width > height;
  }

  private pageStride(): number {
    return this.dualPage ? 2 : 1;
  }

  private pageCount(): number {
    return Math.max(1, Math.ceil(this.readingLength() / this.pageStride()));
  }

  private pageStarts(): number[] {
    const starts: number[] = [];
    const stride: number = this.pageStride();
    const total: number = this.readingLength();
    for (let index: number = 0; index < total; index += stride) {
      starts.push(index);
    }
    return starts;
  }

  private pageLabel(): string {
    const total: number = Math.max(1, this.readingLength());
    if (this.isPdfBook()) {
      return `${this.currentPassageIndex + 1} / ${total}`;
    }
    const firstPassage: number = Math.min(this.displayPageIndex * this.pageStride(), total - 1);
    const start: number = firstPassage + 1;
    if (this.dualPage && firstPassage + 1 < total) {
      return `${start}–${start + 1} / ${total}`;
    }
    return `${start} / ${total}`;
  }

  private passageTitle(index: number): string {
    if (this.isPdfBook()) {
      return `第 ${index + 1} 页`;
    }
    return this.reading.passages[index].title ??
      (this.reading.complete ? `第 ${index + 1} 阅读页` : `節選 ${index + 1}`);
  }

  private minimumFontSize(): number {
    return this.viewportWidth >= 1140 || this.viewportHeight >= 1140 ? 20 : 18;
  }

  private maximumFontSize(): number {
    return this.viewportWidth >= 1140 || this.viewportHeight >= 1140 ? 28 : 24;
  }

  private clampFontSize(value: number): number {
    return Math.max(this.minimumFontSize(), Math.min(Math.round(value), this.maximumFontSize()));
  }

  private saveStyle(): void {
    this.hasSavedStyle = true;
    ReaderPreferences.saveStyle(this.hostContext(), {
      fontSize: this.fontSize,
      lineHeight: this.lineHeight,
      flipMode: this.flipMode,
      themeIndex: 0
    });
  }

  private saveProgress(): void {
    ReaderPreferences.saveProgress(this.hostContext(), this.reading.id, {
      resourceIndex: this.currentPassageIndex,
      domPos: '',
      pageOffset: 0
    });
  }

  private selectFlipMode(index: number): void {
    if (index < 0 || index > 1 || this.flipMode === index) {
      return;
    }
    this.flipMode = index;
    this.flipIndexes = [index];
    this.saveStyle();
  }

  private onFontSizeChange(value: number, mode: SliderChangeMode): void {
    this.fontSize = this.clampFontSize(value);
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.saveStyle();
    }
  }

  private onLineHeightChange(value: number, mode: SliderChangeMode): void {
    this.lineHeight = Math.max(1.5, Math.min(Math.round(value * 10) / 10, 2.3));
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.saveStyle();
    }
  }

  private beginPinch(): void {
    if (this.isPdfBook()) {
      return;
    }
    this.pinchStartFontSize = this.fontSize;
    this.pinching = true;
  }

  private updatePinch(event: GestureEvent): void {
    if (this.isPdfBook() || !this.pinching) {
      return;
    }
    const pinchEvent: PinchGestureEvent = event as PinchGestureEvent;
    this.fontSize = this.clampFontSize(this.pinchStartFontSize * pinchEvent.scale);
  }

  private finishPinch(): void {
    if (!this.pinching) {
      return;
    }
    this.pinching = false;
    this.saveStyle();
  }

  private openCatalog(): void {
    this.panelKind = 0;
    this.panelOpen = true;
  }

  private openSettings(): void {
    this.panelKind = 1;
    this.panelOpen = true;
  }

  private askCurrentPassage(selection?: string): void {
    const passage: ReadingPassage | undefined = this.reading.passages[this.currentPassageIndex];
    const content: string = selection !== undefined && selection.length > 0 ? selection :
      (passage !== undefined && passage.text.length > 0 ? passage.text : this.reading.title);
    let detail: string = `作品：${this.reading.title}\n作者：${this.reading.author}\n简介：${this.reading.summary}`;
    if (passage !== undefined && passage.text.length > 0) {
      detail = `${detail}\n原文：${passage.text}`;
    }
    if (!this.isPdfBook() && passage !== undefined && passage.note.length > 0) {
      detail = `${detail}\n学习提示：${passage.note}`;
    }
    if (this.reading.sourceUrl.length > 0) {
      detail = `${detail}\n来源：${this.reading.sourceUrl}`;
    }
    this.onAsk(AiInquiryFactory.selection(content, `阅读 · ${this.reading.title}`, detail));
  }

  private jumpToPassage(index: number): void {
    const next: number = this.safePassageIndex(index);
    this.currentPassageIndex = next;
    this.displayPageIndex = Math.floor(next / this.pageStride());
    if (this.isPdfBook()) {
      this.pdfJumpPage = next;
    } else {
      this.pageController.changeIndex(this.displayPageIndex, true);
    }
    this.saveProgress();
    this.panelOpen = false;
    if (this.narrationPlaying && Date.now() >= this.ignorePageSyncUntil) {
      void this.seekNarrationToPage(next);
    }
  }

  private onPdfPageChanged(index: number): void {
    this.currentPassageIndex = this.safePassageIndex(index);
    this.displayPageIndex = this.currentPassageIndex;
    this.saveProgress();
    if (this.narrationPlaying && Date.now() >= this.ignorePageSyncUntil &&
      index !== this.lastNarrationPage) {
      void this.seekNarrationToPage(index);
    }
  }

  private onPageChange(index: number): void {
    this.displayPageIndex = Math.max(0, Math.min(index, this.pageCount() - 1));
    this.currentPassageIndex = this.safePassageIndex(this.displayPageIndex * this.pageStride());
    this.saveProgress();
  }

  private toggleControls(): void {
    if (!this.panelOpen && !this.pinching) {
      this.controlsVisible = !this.controlsVisible;
    }
  }

  private handleReaderScroll(yOffset: number, scrollSource: ScrollSource): void {
    if (this.panelOpen || Math.abs(yOffset) < 1) {
      return;
    }
    // Spring bounce at the bottom looks like an upward scroll and would
    // otherwise pull the chrome back immediately after a downward swipe.
    if (scrollSource === ScrollSource.EDGE_EFFECT) {
      return;
    }
    this.controlsVisible = yOffset < 0;
  }

  private updateViewport(width: Length, height: Length): void {
    const nextWidth: number = typeof width === 'number' ? width : Number.parseFloat(width as string);
    const nextHeight: number = typeof height === 'number' ? height : Number.parseFloat(height as string);
    if (Number.isNaN(nextWidth) || Number.isNaN(nextHeight) || nextWidth <= 0 || nextHeight <= 0) {
      return;
    }
    const oldStride: number = this.pageStride();
    this.viewportWidth = nextWidth;
    this.viewportHeight = nextHeight;
    this.dualPage = this.isWideLandscape(nextWidth, nextHeight) && !this.forceSinglePage;
    if (!this.hasSavedStyle) {
      this.fontSize = nextWidth >= 1140 || nextHeight >= 1140 ? 24 : 22;
    } else {
      this.fontSize = this.clampFontSize(this.fontSize);
    }
    if (oldStride !== this.pageStride()) {
      this.displayPageIndex = Math.floor(this.currentPassageIndex / this.pageStride());
      this.pageController.changeIndex(this.displayPageIndex, false);
    }
  }

  private togglePageLayout(): void {
    if (!this.isWideLandscape()) {
      return;
    }
    this.forceSinglePage = !this.forceSinglePage;
    this.dualPage = !this.forceSinglePage;
    this.displayPageIndex = Math.floor(this.currentPassageIndex / this.pageStride());
    if (!this.isPdfBook()) {
      this.pageController.changeIndex(this.displayPageIndex, true);
    }
  }

  private bottomSafeInset(): number {
    return systemGestureInset(this.avoidAreas);
  }

  private readerAction(icon: Resource, label: string, action: () => void): ActionBarButton {
    return new ActionBarButton({
      baseIconSymbolGlyphModifier: new SymbolGlyphModifier(icon)
        .fontSize(22)
        .fontColor([$r('sys.color.icon_primary')]),
      accessibilityText: label,
      hoverTips: label,
      onClick: action
    });
  }

  private endActions(): ActionBarButton[] {
    const actions: ActionBarButton[] = [];
    if (this.isWideLandscape()) {
      actions.push(this.readerAction($r('sys.symbol.rectangle_split_2x1'),
        this.dualPage ? '切换单页' : '切换双页', () => this.togglePageLayout()));
    }
    actions.push(this.readerAction($r('sys.symbol.gearshape_fill'), '阅读设置', () => this.openSettings()));
    return actions;
  }

  private actionBarStyle(): ActionBarStyle {
    return new ActionBarStyle({
      height: LengthMetrics.vp(56),
      innerSpace: LengthMetrics.vp(8),
      startSpace: LengthMetrics.vp(8),
      endSpace: LengthMetrics.vp(8),
      margin: LengthMetrics.vp(0),
      backgroundBlurStyle: BlurStyle.NONE
    });
  }

  build() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        this.readerCanvas()
        if (this.controlsVisible) {
          this.bottomControls()
        } else if (this.hasNarration() && this.narrationPlaying) {
          Column() {
            this.narrationChip()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ bottom: this.bottomSafeInset() + 10 })
        }
        if (this.pinching && !this.isPdfBook()) {
          Text(`${this.fontSize} fp`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .borderRadius(22)
            .backgroundColor(Color.Transparent)
            .systemMaterial(FLOATING_CHROME_MATERIAL)
            .position({ x: '50%', y: '48%' })
            .translate({ x: '-50%', y: '-50%' })
        }
      }
      .width('100%')
      .height('100%')
      .onClick(() => this.toggleControls())
      .gesture(
        PinchGesture({ fingers: 2 })
          .onActionStart(() => this.beginPinch())
          .onActionUpdate((event: GestureEvent) => this.updatePinch(event))
          .onActionEnd(() => this.finishPinch())
          .onActionCancel(() => this.finishPinch())
      )
    }
    .titleBar({
      // This page declares its own titleBar instead of using ImmersiveBackChrome,
      // so it needs the same opt-in: keep the back button and title below the
      // status bar while the bar background still extends into it.
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        originalStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent,
            maskExtraHeight: 0,
            blurRadius: 36
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            backIconStyle: {
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent,
            maskExtraHeight: 0,
            blurRadius: 36
          }
        },
        blurStrategy: BlurStrategy.ADAPTIVE,
        thermoCtrl: true,
        systemMaterialEffect: preferredImmersiveMaterial()
      },
      content: {
        title: {
          mainTitle: this.reading.title,
          subTitle: `${this.reading.author} · ${this.pageLabel()}`,
          mainTitleAccessibilityText: this.reading.title,
          mainTitleSize: TitleSize.TITLE_S
        },
        backIcon: {
          icon: $r('sys.symbol.chevron_left'),
          label: '返回',
          action: this.onBack
        },
        divider: {
          showType: DividerShowType.OFF
        }
      }
    })
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideTitleBar(!this.controlsVisible, true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor(Color.Transparent)
    .onAreaChange((oldArea: Area, newArea: Area) => this.updateViewport(newArea.width, newArea.height))
    .bindSheet($$this.panelOpen, this.readerPanel(), {
      height: this.panelKind === 0 ? SheetSize.LARGE : SheetSize.MEDIUM,
      preferType: SheetType.BOTTOM,
      title: { title: this.panelKind === 0 ? '目录' : '阅读设置' },
      dragBar: true,
      showClose: true,
      blurStyle: BlurStyle.COMPONENT_REGULAR,
      backgroundColor: $r('app.color.surface_raised'),
      maskColor: '#33202124',
      onDisappear: () => this.panelOpen = false
    })
  }

  @Builder
  private readerCanvas() {
    if (this.isPdfBook()) {
      this.pdfCanvas()
    } else {
      this.pagedCanvas()
    }
  }

  @Builder
  private pdfCanvas() {
    if (this.pdfFailed || this.pdfPath.length === 0) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.book_pages'))
          .fontSize(34)
          .fontColor([$r('app.color.ink_muted')])
        Text('这份官方电子书未能打开')
          .fontSize(15)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      PdfReadingCanvas({
        pdfPath: this.pdfPath,
        startPage: this.currentPassageIndex,
        flipMode: this.flipMode,
        dualPage: this.dualPage,
        jumpPage: this.pdfJumpPage,
        highlightKey: this.highlightKey,
        highlightPage: this.highlightPage,
        highlightRects: this.highlightRects,
        onPageChanged: (index: number) => this.onPdfPageChanged(index),
        onFailed: () => {
          this.pdfFailed = true;
        }
      })
        .width('100%')
        .height('100%')
    }
  }

  @Builder
  private pagedCanvas() {
    Swiper(this.pageController) {
      if (this.readingLength() === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.book_pages'))
            .fontSize(34)
            .fontColor([$r('app.color.ink_muted')])
          Text('暂无可阅读内容')
            .fontSize(15)
            .fontColor($r('app.color.ink_muted'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        ForEach(this.pageStarts(), (startIndex: number) => {
          Stack({ alignContent: Alignment.Center }) {
            if (this.dualPage) {
              this.dualPageContent(startIndex)
            } else {
              this.singlePageContent(startIndex)
            }
          }
          .width('100%')
          .height('100%')
        }, (startIndex: number) => `${this.dualPage ? 'dual' : 'single'}-${startIndex}`)
      }
    }
    .width('100%')
    .height('100%')
    .index(this.displayPageIndex)
    .indicator(false)
    .loop(false)
    .vertical(this.flipMode === 1)
    .curve(Curve.Friction)
    .duration(280)
    .onChange((index: number) => this.onPageChange(index))
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private singlePageContent(index: number) {
    Row() {
      Stack() {
        this.passagePage(index, false)
      }
      .layoutWeight(1)
      .constraintSize({ maxWidth: 760 })
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private dualPageContent(startIndex: number) {
    Row() {
      Stack() {
        this.passagePage(startIndex, true)
      }
      .layoutWeight(1)
      .height('100%')

      Divider()
        .vertical(true)
        .height('82%')
        .strokeWidth(0.5)
        .color($r('app.color.line'))

      Stack() {
        if (startIndex + 1 < this.readingLength()) {
          this.passagePage(startIndex + 1, true)
        } else {
          Column({ space: 8 }) {
            Text('完')
              .fontSize(20)
              .fontColor($r('app.color.ink_muted'))
            Text(this.reading.title)
              .fontSize(13)
              .fontColor($r('app.color.ink_muted'))
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('96%')
    .height('100%')
    .constraintSize({ maxWidth: 1320 })
  }

  @Builder
  private passagePage(index: number, compact: boolean) {
    Scroll() {
      Column() {
        Text(this.passageTitle(index))
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.ink_muted'))
          .margin({ bottom: 14 })
        Text(this.reading.passages[index].text)
          .width('100%')
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('app.color.ink'))
          .lineHeight(this.fontSize * this.lineHeight)
          .margin({ bottom: this.fontSize * this.lineHeight * 0.5 })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(this.reading.passages[index].text,
            (selection: string) => {
              this.currentPassageIndex = index;
              this.askCurrentPassage(selection);
            }))
        Column({ space: 7 }) {
          Text('学习提示')
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
          Text(this.reading.passages[index].note)
            .width('100%')
            .fontSize(14)
            .lineHeight(23)
            .fontColor($r('app.color.ink_muted'))
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .margin({ top: compact ? 24 : 30 })
        .border({ width: 0.5, color: $r('app.color.line'), radius: 18 })

        if (index === this.reading.passages.length - 1) {
          Column({ space: 5 }) {
            Text(this.reading.sourceName)
              .fontSize(11)
              .fontColor($r('app.color.ink_muted'))
            Text(this.reading.sourceUrl)
              .fontSize(11)
              .fontColor($r('app.color.ink_muted'))
            Text(this.reading.rights)
              .fontSize(11)
              .lineHeight(17)
              .fontColor($r('app.color.ink_muted'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 28, bottom: 24 })
          .opacity(0.76)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: compact ? 34 : 28,
        right: compact ? 34 : 28,
        // HdsNavigation has no overlay/stack title bar mode (plain Navigation
        // has BarStyle.STACK; HDS does not expose barStyle at all), so
        // hideTitleBar(true) removes the bar's 56vp (MINI) layout height and
        // the content area shifts up by that much — the text visibly jumps.
        // Adding the reclaimed height back as top padding keeps the first line
        // at the same screen position while the reading area gains the space
        // at the bottom instead.
        top: 16 + (this.controlsVisible ? 0 : READER_TITLE_BAR_HEIGHT),
        bottom: 96
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onWillScroll((xOffset: number, yOffset: number, scrollState: ScrollState, scrollSource: ScrollSource) => {
      this.handleReaderScroll(yOffset, scrollSource);
    })
    .onClick(() => this.currentPassageIndex = index)
  }

  @Builder
  private narrationChip() {
    Row({ space: 6 }) {
      SymbolGlyph(this.narrationPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
        .fontSize(16)
        .fontColor([$r('sys.color.icon_primary')])
      Text(this.narrationPlaying ? '暂停' : '朗读')
        .fontSize(12)
        .fontColor($r('sys.color.font_primary'))
    }
    .padding({ left: 12, right: 14, top: 6, bottom: 6 })
    .borderRadius(16)
    .backgroundColor(Color.Transparent)
    .systemMaterial(FLOATING_CHROME_MATERIAL)
    .accessibilityText(this.narrationPlaying ? '暂停朗读' : '朗读')
    .onClick(() => {
      void this.toggleNarration();
    })
  }

  @Builder
  private bottomControls() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(this.pageLabel())
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 13, right: 13, top: 6, bottom: 6 })
          .borderRadius(16)
          .backgroundColor(Color.Transparent)
          .systemMaterial(FLOATING_CHROME_MATERIAL)
        if (this.hasNarration()) {
          this.narrationChip()
        }
      }
      Column() {
        HdsActionBar({
          startButtons: [
            this.readerAction($r('sys.symbol.book_pages_fill'), '目录', () => this.openCatalog())
          ],
          endButtons: this.endActions(),
          actionBarStyle: this.actionBarStyle(),
          blurStrategy: BlurStrategy.ADAPTIVE
        })
      }
      .width('100%')
      .borderRadius(28)
      .systemMaterial(FLOATING_CHROME_MATERIAL)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 16, right: 16, bottom: this.bottomSafeInset() + 10 })
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ y: 18 }))
      .animation({ curve: Curve.Friction, duration: 220 }))
  }

  @Builder
  private readerPanel() {
    if (this.panelKind === 0) {
      this.catalogPanel()
    } else {
      this.settingsPanel()
    }
  }

  @Builder
  private catalogPanel() {
    List({ space: 0 }) {
      ListItem() {
        Column({ space: 5 }) {
          Text(this.reading.title)
            .width('100%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(`${this.reading.author} · ${this.reading.titleReading}`)
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.ink_muted'))
          Text(this.reading.summary)
            .width('100%')
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.ink_muted'))
            .margin({ top: 6 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 22, top: 10, bottom: 20 })
      }

      ForEach(this.reading.passages, (passage: ReadingPassage, index: number) => {
        ListItem() {
          this.catalogRow(this.passageTitle(index), index, () => this.jumpToPassage(index))
        }
      }, (passage: ReadingPassage, index: number) => `${index}-${passage.text}`)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private catalogRow(title: string, index: number, action: () => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .width('100%')
          .fontSize(16)
          .fontWeight(index === this.currentPassageIndex ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(index === this.currentPassageIndex ? $r('app.color.accent') : $r('app.color.ink'))
        Text(index === this.currentPassageIndex ? '正在阅读' :
          (this.isPdfBook() ? `绘本 · 第 ${index + 1} 页` :
            (this.reading.complete ? `全文 · 第 ${index + 1} 阅读页` : `第 ${index + 1} 节`)))
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.ink_muted'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('app.color.ink_muted')])
    }
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding({ left: 22, right: 22, top: 10, bottom: 10 })
    .border({ width: { top: 0.5 }, color: $r('app.color.line') })
    .accessibilityText(`${title}，${index === this.currentPassageIndex ? '正在阅读' : ''}`)
    .onClick(action)
  }

  @Builder
  private settingsPanel() {
    Scroll() {
      Column({ space: 22 }) {
        Column({ space: 9 }) {
          Text('翻页方向')
            .width('100%')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink_muted'))
          SegmentButton({
            options: this.flipOptions,
            selectedIndexes: this.flipIndexes,
            onItemClicked: (index: number) => this.selectFlipMode(index)
          })
            .width('100%')
            .height(44)
            .clip(true)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.isPdfBook()) {
          Text(this.hasNarration() ?
            '绘本按官方电子书原页显示。朗读是官方未改动的音频，读到哪一句就翻到那一页并标出那一句。' :
            '绘本按官方电子书原页显示，字号和行高跟随原版。')
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.ink_muted'))
        }

        if (this.isWideLandscape()) {
          Row() {
            Column({ space: 3 }) {
              Text('双页阅读')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink'))
              Text('宽屏横向时默认开启，可手动切换')
                .fontSize(12)
                .fontColor($r('app.color.ink_muted'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Toggle({ type: ToggleType.Switch, isOn: this.dualPage })
              .selectedColor($r('app.color.accent'))
              .onChange(() => this.togglePageLayout())
          }
          .width('100%')
        }

        if (!this.isPdfBook()) {
        Column({ space: 8 }) {
          Row() {
            Text('字号')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink_muted'))
            Blank()
            Text(`${this.fontSize} fp`)
              .fontSize(13)
              .fontColor($r('app.color.ink'))
          }
          .width('100%')
          Slider({
            value: this.fontSize,
            min: this.minimumFontSize(),
            max: this.maximumFontSize(),
            step: 1,
            style: SliderStyle.InSet
          })
            .width('100%')
            .selectedColor($r('app.color.accent'))
            .onChange((value: number, mode: SliderChangeMode) => this.onFontSizeChange(value, mode))
          Text('也可以在正文上双指缩放')
            .width('100%')
            .fontSize(11)
            .fontColor($r('app.color.ink_muted'))
        }
        .width('100%')

        Column({ space: 8 }) {
          Row() {
            Text('行高')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink_muted'))
            Blank()
            Text(`${this.lineHeight.toFixed(1)} ×`)
              .fontSize(13)
              .fontColor($r('app.color.ink'))
          }
          .width('100%')
          Slider({ value: this.lineHeight, min: 1.5, max: 2.3, step: 0.1, style: SliderStyle.InSet })
            .width('100%')
            .selectedColor($r('app.color.accent'))
            .onChange((value: number, mode: SliderChangeMode) => this.onLineHeightChange(value, mode))
        }
        .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 14, bottom: 34 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
