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
import { preferredImmersiveMaterial } from '../../common/ImmersiveMaterial';
import { ReadingPassage, ReadingWork } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ReaderPreferences, ReaderProgressSnapshot, ReaderStyleSnapshot } from '../../services/ReaderPreferences';
import { aiTextSelectionMenu } from '../components/AiTextSelection';

interface ReaderThemeOption {
  name: string;
  color: string;
  fontColor: string;
  mutedColor: string;
  dividerColor: string;
}

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
  passages: []
};

const READER_THEMES: ReaderThemeOption[] = [
  {
    name: '宣纸',
    color: '#F4E6C6',
    fontColor: '#2C261F',
    mutedColor: '#786B59',
    dividerColor: '#3D786B59'
  },
  {
    name: '米白',
    color: '#FAF7EF',
    fontColor: '#24221F',
    mutedColor: '#716D64',
    dividerColor: '#35716D64'
  },
  {
    name: '青绿',
    color: '#DCE8D8',
    fontColor: '#243027',
    mutedColor: '#617064',
    dividerColor: '#35617064'
  },
  {
    name: '夜间',
    color: '#1E211F',
    fontColor: '#EEF1EC',
    mutedColor: '#A8B0AA',
    dividerColor: '#4DA8B0AA'
  }
];

// Height HdsNavigation's MINI title bar occupies in layout. Hiding the bar
// reclaims exactly this much, so the content must compensate to avoid a jump.
const READER_TITLE_BAR_HEIGHT: number = 56;

// Keep this page on system ArkUI components. Reader Kit's kitview HSP is not present on simulators
// and some unsupported devices, where a static Reader Kit import aborts before fallback code can run.
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
  @State private themeIndex: number = 0;
  @State private flipIndexes: number[] = [0];
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 780;
  @State private dualPage: boolean = false;
  @State private forceSinglePage: boolean = false;
  @State private pinching: boolean = false;

  private pageController: SwiperController = new SwiperController();
  private pinchStartFontSize: number = 22;
  private hasSavedStyle: boolean = false;
  private restoreControlsTimer: number = -1;
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
    this.themeIndex = Math.max(0, Math.min(style.themeIndex, READER_THEMES.length - 1));
    this.flipIndexes = [this.flipMode];
    const progress: ReaderProgressSnapshot = ReaderPreferences.progress(this.hostContext(), this.reading.id);
    this.currentPassageIndex = this.safePassageIndex(progress.resourceIndex);
    this.displayPageIndex = this.currentPassageIndex;
  }

  aboutToDisappear(): void {
    if (this.restoreControlsTimer >= 0) {
      clearTimeout(this.restoreControlsTimer);
      this.restoreControlsTimer = -1;
    }
  }

  private hostContext(): common.Context {
    return this.getUIContext().getHostContext() as common.Context;
  }

  private theme(): ReaderThemeOption {
    return READER_THEMES[Math.max(0, Math.min(this.themeIndex, READER_THEMES.length - 1))];
  }

  private safePassageIndex(index: number): number {
    if (this.reading.passages.length === 0) {
      return 0;
    }
    return Math.max(0, Math.min(index, this.reading.passages.length - 1));
  }

  private isWideLandscape(width: number = this.viewportWidth, height: number = this.viewportHeight): boolean {
    return width >= 840 && width > height;
  }

  private pageStride(): number {
    return this.dualPage ? 2 : 1;
  }

  private pageCount(): number {
    return Math.max(1, Math.ceil(this.reading.passages.length / this.pageStride()));
  }

  private pageStarts(): number[] {
    const starts: number[] = [];
    const stride: number = this.pageStride();
    for (let index: number = 0; index < this.reading.passages.length; index += stride) {
      starts.push(index);
    }
    return starts;
  }

  private pageLabel(): string {
    const total: number = Math.max(1, this.reading.passages.length);
    const firstPassage: number = Math.min(this.displayPageIndex * this.pageStride(), total - 1);
    const start: number = firstPassage + 1;
    if (this.dualPage && firstPassage + 1 < this.reading.passages.length) {
      return `${start}–${start + 1} / ${total}`;
    }
    return `${start} / ${total}`;
  }

  private passageTitle(index: number): string {
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
      themeIndex: this.themeIndex
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

  private selectTheme(index: number): void {
    if (index < 0 || index >= READER_THEMES.length || this.themeIndex === index) {
      return;
    }
    this.themeIndex = index;
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
    this.pinchStartFontSize = this.fontSize;
    this.pinching = true;
  }

  private updatePinch(event: GestureEvent): void {
    const pinchEvent: PinchGestureEvent = event as PinchGestureEvent;
    this.fontSize = this.clampFontSize(this.pinchStartFontSize * pinchEvent.scale);
  }

  private finishPinch(): void {
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
      passage?.text ?? this.reading.title;
    const detail: string = passage === undefined ?
      `作品：${this.reading.title}\n作者：${this.reading.author}\n简介：${this.reading.summary}` :
      `作品：${this.reading.title}\n作者：${this.reading.author}\n原文：${passage.text}\n学习提示：${passage.note}`;
    this.onAsk(AiInquiryFactory.selection(content, `阅读 · ${this.reading.title}`, detail));
  }

  private jumpToPassage(index: number): void {
    const next: number = this.safePassageIndex(index);
    this.currentPassageIndex = next;
    this.displayPageIndex = Math.floor(next / this.pageStride());
    this.pageController.changeIndex(this.displayPageIndex, true);
    this.saveProgress();
    this.panelOpen = false;
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

  private handleReaderScroll(yOffset: number): void {
    if (this.panelOpen || Math.abs(yOffset) < 1) {
      return;
    }
    this.controlsVisible = yOffset < 0;
  }

  private restoreControlsSoon(): void {
    if (this.restoreControlsTimer >= 0) {
      clearTimeout(this.restoreControlsTimer);
    }
    this.restoreControlsTimer = setTimeout(() => {
      this.controlsVisible = true;
      this.restoreControlsTimer = -1;
    }, 900);
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
    this.pageController.changeIndex(this.displayPageIndex, true);
  }

  private bottomSafeInset(): number {
    return Math.max(this.avoidAreas.navigationIndicator.bottomRect.height,
      this.avoidAreas.cutout.bottomRect.height, this.avoidAreas.statusBar.bottomRect.height);
  }

  private readerAction(icon: Resource, label: string, action: () => void): ActionBarButton {
    return new ActionBarButton({
      baseIconSymbolGlyphModifier: new SymbolGlyphModifier(icon).fontSize(22),
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
      backgroundBlurStyle: BlurStyle.COMPONENT_REGULAR
    });
  }

  build() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        this.readerCanvas()
        if (this.controlsVisible) {
          this.bottomControls()
        }
        if (this.pinching) {
          Text(`${this.fontSize} fp`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .borderRadius(22)
            .backgroundColor($r('app.color.surface_raised'))
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
              mainTitleColor: this.theme().fontColor,
              subTitleColor: this.theme().mutedColor
            },
            backIconStyle: {
              iconColor: this.theme().fontColor
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
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor(this.theme().color)
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
    Swiper(this.pageController) {
      if (this.reading.passages.length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.book_pages'))
            .fontSize(34)
            .fontColor([this.theme().mutedColor])
          Text('暂无可阅读内容')
            .fontSize(15)
            .fontColor(this.theme().mutedColor)
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
    .backgroundColor(this.theme().color)
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
        .color(this.theme().dividerColor)

      Stack() {
        if (startIndex + 1 < this.reading.passages.length) {
          this.passagePage(startIndex + 1, true)
        } else {
          Column({ space: 8 }) {
            Text('完')
              .fontSize(20)
              .fontColor(this.theme().mutedColor)
            Text(this.reading.title)
              .fontSize(13)
              .fontColor(this.theme().mutedColor)
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
        Text(`${this.reading.genre} · ${this.reading.level}`)
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().mutedColor)
        Text(this.reading.title)
          .width('100%')
          .fontSize(compact ? 25 : 28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().fontColor)
          .margin({ top: 8 })
        Text(`${this.reading.author} · ${this.reading.titleReading}`)
          .width('100%')
          .fontSize(13)
          .fontColor(this.theme().mutedColor)
          .margin({ top: 6, bottom: compact ? 26 : 36 })
        Text(this.passageTitle(index))
          .width('100%')
          .fontSize(12)
          .fontColor(this.theme().mutedColor)
          .margin({ bottom: 14 })
        Text(this.reading.passages[index].text)
          .width('100%')
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Regular)
          .fontColor(this.theme().fontColor)
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
            .fontColor(this.theme().fontColor)
          Text(this.reading.passages[index].note)
            .width('100%')
            .fontSize(14)
            .lineHeight(23)
            .fontColor(this.theme().mutedColor)
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .margin({ top: compact ? 24 : 30 })
        .border({ width: 0.5, color: this.theme().dividerColor, radius: 18 })

        if (index === this.reading.passages.length - 1) {
          Column({ space: 5 }) {
            Text(this.reading.sourceName)
              .fontSize(11)
              .fontColor(this.theme().mutedColor)
            Text(this.reading.sourceUrl)
              .fontSize(11)
              .fontColor(this.theme().mutedColor)
            Text(this.reading.rights)
              .fontSize(11)
              .lineHeight(17)
              .fontColor(this.theme().mutedColor)
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
        top: (compact ? 94 : 112) + (this.controlsVisible ? 0 : READER_TITLE_BAR_HEIGHT),
        bottom: 96
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onWillScroll((xOffset: number, yOffset: number, scrollState: ScrollState, scrollSource: ScrollSource) => {
      this.handleReaderScroll(yOffset);
    })
    .onScrollStop(() => this.restoreControlsSoon())
    .onClick(() => this.currentPassageIndex = index)
  }

  @Builder
  private bottomControls() {
    Column({ space: 10 }) {
      Text(this.pageLabel())
        .fontSize(12)
        .fontColor($r('app.color.ink_muted'))
        .padding({ left: 13, right: 13, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor($r('app.color.surface_raised'))
      HdsActionBar({
        startButtons: [
          this.readerAction($r('sys.symbol.book_pages_fill'), '目录', () => this.openCatalog())
        ],
        primaryButton: this.readerAction(
          $r('sys.symbol.translate_square_fill'), '询问 AI', () => this.askCurrentPassage()),
        endButtons: this.endActions(),
        actionBarStyle: this.actionBarStyle(),
        blurStrategy: BlurStrategy.ADAPTIVE
      })
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
          (this.reading.complete ? `全文 · 第 ${index + 1} 阅读页` : `第 ${index + 1} 节`))
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

        Column({ space: 10 }) {
          Text('页面主题')
            .width('100%')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink_muted'))
          Row({ space: 12 }) {
            ForEach(READER_THEMES, (theme: ReaderThemeOption, index: number) => {
              Column({ space: 7 }) {
                Stack({ alignContent: Alignment.Center }) {
                  if (this.themeIndex === index) {
                    SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                      .fontSize(22)
                      .fontColor([theme.fontColor])
                  }
                }
                .width(42)
                .height(42)
                .borderRadius(21)
                .backgroundColor(theme.color)
                .border({
                  width: this.themeIndex === index ? 2 : 0.5,
                  color: this.themeIndex === index ? $r('app.color.accent') : $r('app.color.line')
                })
                Text(theme.name)
                  .fontSize(11)
                  .fontColor($r('app.color.ink_muted'))
              }
              .layoutWeight(1)
              .accessibilityText(`页面主题，${theme.name}${this.themeIndex === index ? '，已选择' : ''}`)
              .onClick(() => this.selectTheme(index))
            }, (theme: ReaderThemeOption) => theme.name)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
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
