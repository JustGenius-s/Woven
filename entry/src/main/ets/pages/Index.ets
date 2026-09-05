import { common } from '@kit.AbilityKit';
import { curves, window } from '@kit.ArkUI';
import {
  BlurStrategy,
  DividerMode,
  HdsBarStyle,
  HdsTabs,
  HdsTabsController
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import {
  CONTENT_MAX_WIDTH,
  FLOATING_TAB_BAR_BOTTOM_MARGIN,
  FLOATING_TAB_MASK_HEIGHT,
  MOTION_DURATION,
  systemGestureInset
} from '../common/AppTheme';
import { bottomBarImmersiveMaterial } from '../common/ImmersiveMaterial';
import { AppSection, LearningJourney, PracticeScenario, ReadingWork } from '../model/ContentModels';
import { GrammarWork } from '../model/GrammarModels';
import { AiInquiryContext } from '../model/DeepSeekModels';
import { VideoItem } from '../model/VideoModels';
import {
  CloudSyncPhase,
  CloudSyncSnapshot,
  HuaweiAccountPhase,
  HuaweiAccountSnapshot
} from '../model/SyncModels';
import { ContentRepository } from '../services/ContentRepository';
import {
  DISTRIBUTED_SYNC_PERMISSION_REQUIRED,
  DistributedSyncPermission
} from '../services/DistributedSyncPermission';
import { HuaweiAccountService } from '../services/HuaweiAccountService';
import { LearningPreferences } from '../services/LearningPreferences';
import { LearningSyncCoordinator } from '../services/LearningSyncCoordinator';
import { JapaneseTtsService } from '../services/JapaneseTtsService';
import { KanaLookupService } from '../services/KanaLookupService';
import { MusicPlaybackService } from '../services/MusicPlaybackService';
import { VideoLibraryStore } from '../services/VideoLibraryStore';
import { VideoPlaybackService } from '../services/VideoPlaybackService';
import { VocabularyLearningStore } from '../services/VocabularyLearningStore';
import { BasicsPage } from '../views/pages/BasicsPage';
import { ExplorePage } from '../views/pages/ExplorePage';
import { GrammarLessonPage } from '../views/pages/GrammarLessonPage';
import { LearnPage } from '../views/pages/LearnPage';
import { MePage } from '../views/pages/MePage';
import { PracticeSessionPage } from '../views/pages/PracticeSessionPage';
import { ReadingPage } from '../views/pages/ReadingPage';
import { SettingsPage } from '../views/pages/SettingsPage';
import { VocabularyPage } from '../views/pages/VocabularyPage';
import { VocabularyStudyPage } from '../views/pages/VocabularyStudyPage';
import { VideoPlayerPage } from '../views/pages/VideoPlayerPage';
import { ImmersiveBackdrop } from '../views/components/ImmersiveCanvas';
import { LaunchSplash } from '../views/components/LaunchSplash';
import { ContextAiPanel } from '../views/components/ContextAiPanel';
import { KanaLookupSheet } from '../views/components/KanaLookupSheet';

@Entry
@Component
struct Index {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  @State private section: number = AppSection.LEARN;
  @State private deepSeekApiKey: string = '';
  @State private minimaxApiKey: string = '';
  @State private settingsOpen: boolean = false;
  @State private activeScenario: PracticeScenario | undefined = undefined;
  @State private activeReading: ReadingWork | undefined = undefined;
  @State private activeGrammar: GrammarWork | undefined = undefined;
  @State private activeVideo: VideoItem | undefined = undefined;
  @State private journeys: LearningJourney[] = [];
  @State private currentJourney: LearningJourney | undefined = undefined;
  @State private journeyStage: number = 0;
  @State private journeyCompletedMask: number = 0;
  @State private activeInquiry: AiInquiryContext | undefined = undefined;
  @State private inquiryPopupOpen: boolean = false;
  // Kana chart opened from a selection menu; the request arrives through
  // KanaLookupService so the menu call sites need no per-page wiring.
  @State private kanaLookupOpen: boolean = false;
  @State private kanaLookupQuery: string = '';
  @State private vocabularyStudyOpen: boolean = false;
  @State private vocabularyStudyLevel: string = 'N5';
  @State private vocabularyStudyWordId: string = '';
  @State private vocabularyStudyWordIds: string[] = [];
  @State private vocabularySceneTone: number = -1;
  @State private vocabularySearchOpen: boolean = false;
  @State private kanaKey: string = 'あ';
  @State private exploreTab: number = 0;
  @State private basicsTab: number = 0;
  @State private grammarId: string = '';
  @State private videoId: string = '';
  @State private videoCount: number = 0;
  @State private lastVideoTitle: string = '';
  @State private readingIndex: number = -1;
  @State private scenarioIndex: number = -1;
  @State private learnedWordCount: number = 0;
  @State private floatingBarsVertical: boolean = true;
  // Tracks the style HdsTabs actually settled on. The collapsed mini bar is the
  // shorter of the two, so its content has to shrink to fit.
  @State private miniBarCollapsed: boolean = true;
  // Last style we asked HdsTabs to use, including the user's tap on the
  // collapsed tab icon. Kept off @State so onBarStyleChange can record it
  // during layout without rebuilding the shell mid-animation.
  private requestedMiniBarStyle: HdsBarStyle = HdsBarStyle.COLLAPSE;
  @State private accountSnapshot: HuaweiAccountSnapshot = {
    phase: HuaweiAccountPhase.SIGNED_OUT,
    unionId: '',
    openId: '',
    detail: ''
  };
  @State private cloudSyncSnapshot: CloudSyncSnapshot = {
    phase: CloudSyncPhase.LOCAL_ONLY,
    lastSyncedAt: 0,
    detail: ''
  };
  @State private splashOpen: boolean = true;

  aboutToAppear(): void {
    KanaLookupService.subscribe(this.kanaLookupListener);
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    const storedSection: number = LearningPreferences.section(context);
    this.section = storedSection >= AppSection.LEARN && storedSection <= AppSection.ME ?
      storedSection : AppSection.LEARN;
    this.deepSeekApiKey = LearningPreferences.deepSeekApiKey(context);
    this.minimaxApiKey = LearningPreferences.minimaxApiKey(context);
    this.journeyStage = LearningPreferences.journeyStage(context);
    this.journeyCompletedMask = LearningPreferences.journeyCompletedMask(context);
    this.kanaKey = LearningPreferences.kanaKey(context);
    this.exploreTab = LearningPreferences.exploreTab(context);
    this.basicsTab = LearningPreferences.basicsTab(context);
    this.grammarId = LearningPreferences.grammarLessonId(context);
    this.refreshVideoLibrary(context);
    this.readingIndex = LearningPreferences.readingIndex(context);
    this.scenarioIndex = LearningPreferences.scenarioIndex(context);
    this.learnedWordCount = VocabularyLearningStore.loadLearnedWords(context).length;
    try {
      this.journeys = ContentRepository.loadJourneys(context);
      const savedJourneyId: string = LearningPreferences.journeyId(context);
      this.currentJourney = this.journeys.length > 0 ? this.journeys[0] : undefined;
      for (let index: number = 0; index < this.journeys.length; index++) {
        if (this.journeys[index].id === savedJourneyId) {
          this.currentJourney = this.journeys[index];
          break;
        }
      }
    } catch (error) {
      this.journeys = [];
      this.currentJourney = undefined;
    }
    JapaneseTtsService.initialize(context);
    MusicPlaybackService.initialize(context, []);
    VideoPlaybackService.initialize(context);
    this.initializeAccountAndSync(context);
    void ContentRepository.prefetchReadings(context);
    void ContentRepository.prefetchGrammar(context);
  }

  aboutToDisappear(): void {
    KanaLookupService.unsubscribe(this.kanaLookupListener);
  }

  private refreshVideoLibrary(context: common.Context): void {
    const videos: VideoItem[] = VideoLibraryStore.load(context);
    this.videoCount = videos.length;
    this.lastVideoTitle = videos.length > 0 ? videos[0].title : '';
  }

  private kanaLookupListener: (query: string) => void = (query: string) => {
    this.kanaLookupQuery = query;
    this.kanaLookupOpen = true;
  };

  private async initializeAccountAndSync(context: common.Context): Promise<void> {
    this.accountSnapshot = HuaweiAccountService.checking();
    this.cloudSyncSnapshot = await LearningSyncCoordinator.initialize(context);
    this.accountSnapshot = await HuaweiAccountService.refresh(context);
    if (this.accountSnapshot.phase === HuaweiAccountPhase.SIGNED_IN) {
      await this.syncLearningState(context, false);
    }
  }

  private async syncLearningState(context: common.Context, requestPermission: boolean): Promise<void> {
    if (this.accountSnapshot.phase !== HuaweiAccountPhase.SIGNED_IN ||
      this.cloudSyncSnapshot.phase === CloudSyncPhase.SYNCING) {
      return;
    }
    const permissionGranted: boolean = await DistributedSyncPermission.ensure(
      context as common.UIAbilityContext, requestPermission);
    if (!permissionGranted) {
      this.cloudSyncSnapshot = {
        phase: CloudSyncPhase.NEEDS_CONFIGURATION,
        lastSyncedAt: this.cloudSyncSnapshot.lastSyncedAt,
        detail: DISTRIBUTED_SYNC_PERMISSION_REQUIRED
      };
      return;
    }
    this.cloudSyncSnapshot = {
      phase: CloudSyncPhase.SYNCING,
      lastSyncedAt: this.cloudSyncSnapshot.lastSyncedAt,
      detail: ''
    };
    this.cloudSyncSnapshot = await LearningSyncCoordinator.syncNow(
      context, this.cloudSyncSnapshot.lastSyncedAt);
    if (this.cloudSyncSnapshot.phase === CloudSyncPhase.SYNCED) {
      this.reloadSyncedLearningState(context);
    }
  }

  private handleAccountChange(snapshot: HuaweiAccountSnapshot): void {
    this.accountSnapshot = snapshot;
    if (snapshot.phase === HuaweiAccountPhase.SIGNED_IN) {
      this.syncLearningState(this.getUIContext().getHostContext() as common.Context, true);
    }
  }

  private reloadSyncedLearningState(context: common.Context): void {
    this.journeyStage = LearningPreferences.journeyStage(context);
    this.journeyCompletedMask = LearningPreferences.journeyCompletedMask(context);
    this.kanaKey = LearningPreferences.kanaKey(context);
    this.refreshVideoLibrary(context);
    this.readingIndex = LearningPreferences.readingIndex(context);
    this.scenarioIndex = LearningPreferences.scenarioIndex(context);
    this.learnedWordCount = VocabularyLearningStore.loadLearnedWords(context).length;
    const journeyId: string = LearningPreferences.journeyId(context);
    for (let index: number = 0; index < this.journeys.length; index++) {
      if (this.journeys[index].id === journeyId) {
        this.currentJourney = this.journeys[index];
        break;
      }
    }
  }

  private selectSection(section: number): void {
    if (section !== AppSection.VOCABULARY) {
      this.vocabularySearchOpen = false;
    }
    this.section = section;
    LearningPreferences.saveSection(this.getUIContext().getHostContext() as common.Context, section);
  }

  private saveKanaKey(key: string): void {
    this.kanaKey = key;
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    LearningPreferences.saveKanaKey(context, key);
    LearningSyncCoordinator.saveKanaProgress(context, key);
  }

  private saveBasicsTab(index: number): void {
    this.basicsTab = Math.max(0, Math.min(index, 1));
    LearningPreferences.saveBasicsTab(
      this.getUIContext().getHostContext() as common.Context, this.basicsTab);
  }

  private openBasicsGrammar(): void {
    this.saveBasicsTab(1);
    this.selectSection(AppSection.KANA);
  }

  private saveGrammarLesson(lesson: GrammarWork): void {
    this.grammarId = lesson.id;
    LearningPreferences.saveGrammarLessonId(
      this.getUIContext().getHostContext() as common.Context, lesson.id);
  }

  private openGrammar(lesson: GrammarWork): void {
    this.saveGrammarLesson(lesson);
    this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.84, 0.18) }, () => {
      this.activeGrammar = lesson;
    });
  }

  private closeGrammar(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.38, 0.88, 0.16) }, () => {
      this.activeGrammar = undefined;
    });
  }

  private saveExploreTab(index: number): void {
    this.exploreTab = Math.max(0, Math.min(index, 2));
    LearningPreferences.saveExploreTab(
      this.getUIContext().getHostContext() as common.Context, this.exploreTab);
  }

  private openExplore(tab: number): void {
    this.saveExploreTab(tab);
    this.selectSection(AppSection.EXPLORE);
  }

  private openVideo(video: VideoItem): void {
    this.videoId = video.id;
    this.refreshVideoLibrary(this.getUIContext().getHostContext() as common.Context);
    this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.84, 0.18) }, () => {
      this.activeVideo = video;
    });
  }

  private closeVideoPlayer(): void {
    this.refreshVideoLibrary(this.getUIContext().getHostContext() as common.Context);
    this.getUIContext().animateTo({ curve: curves.springMotion(0.38, 0.88, 0.16) }, () => {
      this.activeVideo = undefined;
    });
  }

  private saveReadingIndex(index: number): void {
    this.readingIndex = index;
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    LearningPreferences.saveReadingIndex(context, index);
    LearningSyncCoordinator.saveReadingProgress(context, index);
  }

  private openReading(reading: ReadingWork, index: number): void {
    this.saveReadingIndex(index);
    this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.84, 0.18) }, () => {
      this.activeReading = reading;
    });
  }

  private closeReading(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.38, 0.88, 0.16) }, () => {
      this.activeReading = undefined;
    });
  }

  private saveScenarioIndex(index: number): void {
    this.scenarioIndex = index;
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    LearningPreferences.saveScenarioIndex(context, index);
    LearningSyncCoordinator.saveScenarioProgress(context, index);
  }

  private saveDeepSeekApiKey(apiKey: string): void {
    this.deepSeekApiKey = apiKey;
    LearningPreferences.saveDeepSeekApiKey(
      this.getUIContext().getHostContext() as common.Context, apiKey);
  }

  private saveMinimaxApiKey(apiKey: string): void {
    this.minimaxApiKey = apiKey;
    LearningPreferences.saveMinimaxApiKey(
      this.getUIContext().getHostContext() as common.Context, apiKey);
  }

  private startPractice(scenario: PracticeScenario): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.4, 0.84, 0.18) }, () => {
      this.activeScenario = scenario;
    });
  }

  private closePractice(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.36, 0.9, 0.14) }, () => {
      this.activeScenario = undefined;
    });
  }

  private openInquiry(context: AiInquiryContext): void {
    if (this.deepSeekApiKey.trim().length === 0) {
      this.settingsOpen = true;
      return;
    }
    this.activeInquiry = context;
    this.inquiryPopupOpen = true;
  }

  private closeInquiry(): void {
    this.inquiryPopupOpen = false;
  }

  private openVocabularyStudy(level: string, wordId: string, wordIds: string[]): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.84, 0.18) }, () => {
      this.vocabularyStudyLevel = level;
      this.vocabularyStudyWordId = wordId;
      this.vocabularyStudyWordIds = wordIds.slice();
      this.vocabularyStudyOpen = true;
    });
  }

  private closeVocabularyStudy(): void {
    this.learnedWordCount = VocabularyLearningStore.loadLearnedWords(
      this.getUIContext().getHostContext() as common.Context).length;
    this.getUIContext().animateTo({ curve: curves.springMotion(0.38, 0.88, 0.16) }, () => {
      this.vocabularyStudyOpen = false;
      this.vocabularySceneTone = -1;
    });
  }

  private finishInquiryDismissal(): void {
    this.inquiryPopupOpen = false;
    this.activeInquiry = undefined;
  }

  private bottomSafeInset(): number {
    return systemGestureInset(this.avoidAreas);
  }

  private tabsController: HdsTabsController = new HdsTabsController();

  private bindTabScroller(section: AppSection, scroller: Scroller): void {
    this.tabsController.bindScroller(section, scroller);
  }

  private setFloatingBarsCompact(compact: boolean): void {
    const vertical: boolean = !compact;
    if (this.floatingBarsVertical === vertical) {
      return;
    }
    // Only the layout-mode transition requests a new priority. Once the bars
    // are already horizontal, leave requestedMiniBarStyle alone so a later
    // scroll tick cannot undo a tap that expanded the tab bar.
    this.requestedMiniBarStyle = vertical ? HdsBarStyle.COLLAPSE : HdsBarStyle.EXPAND;
    this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.86, 0.16) }, () => {
      this.floatingBarsVertical = vertical;
      this.miniBarCollapsed = vertical;
    });
  }


  private leftSafeInset(): number {
    return Math.max(this.avoidAreas.cutout.leftRect.width, this.avoidAreas.navigationIndicator.leftRect.width,
      this.avoidAreas.statusBar.leftRect.width);
  }

  private rightSafeInset(): number {
    return Math.max(this.avoidAreas.cutout.rightRect.width, this.avoidAreas.navigationIndicator.rightRect.width,
      this.avoidAreas.statusBar.rightRect.width);
  }

  private tabSymbol(normalSymbol: Resource, selectedSymbol: Resource): TabBarSymbol {
    return {
      normal: new SymbolGlyphModifier(normalSymbol),
      selected: new SymbolGlyphModifier(selectedSymbol)
    };
  }

  build() {
    Stack() {
      ImmersiveBackdrop({
        sceneToneIndex: this.vocabularyStudyOpen && !this.settingsOpen ? this.vocabularySceneTone : -1,
        paper: this.activeReading !== undefined || this.activeGrammar !== undefined,
        canvasContent: () => {
          this.appShell()
        }
      })
      if (this.splashOpen) {
        LaunchSplash({
          onFinished: () => {
            this.splashOpen = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    // Opaque backgrounds render above the title bar's material layer and hide
    // the immersive effect (see the "看不到材质效果" FAQ). The window already
    // paints the surface color in EntryAbility, so keeping the root clear lets
    // the material show through.
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private appShell() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.activeVideo !== undefined) {
          VideoPlayerPage({
            video: this.activeVideo,
            onBack: () => this.closeVideoPlayer()
          })
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 18 }))
            .animation({ curve: curves.springMotion(0.42, 0.84, 0.18) }))
        } else if (this.activeGrammar !== undefined) {
          GrammarLessonPage({
            lesson: this.activeGrammar,
            onBack: () => this.closeGrammar()
          })
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ x: 24 }))
            .animation({ curve: curves.springMotion(0.42, 0.84, 0.18) }))
        } else if (this.activeReading !== undefined) {
          ReadingPage({
            reading: this.activeReading,
            onBack: () => this.closeReading(),
            onAsk: (context: AiInquiryContext) => this.openInquiry(context)
          })
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ x: 24 }))
            .animation({ curve: curves.springMotion(0.42, 0.84, 0.18) }))
        } else if (this.activeScenario !== undefined) {
          PracticeSessionPage({
            scenario: this.activeScenario,
            apiKey: this.deepSeekApiKey,
            onExit: () => this.closePractice()
          })
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
            .animation({ curve: curves.springMotion(0.42, 0.82, 0.18) }))
        } else if (this.settingsOpen) {
          SettingsPage({
            initialApiKey: this.deepSeekApiKey,
            initialMinimaxApiKey: this.minimaxApiKey,
            account: this.accountSnapshot,
            syncState: this.cloudSyncSnapshot,
            onBack: () => this.settingsOpen = false,
            onSave: (apiKey: string) => this.saveDeepSeekApiKey(apiKey),
            onSaveMinimax: (apiKey: string) => this.saveMinimaxApiKey(apiKey),
            onSync: () => this.syncLearningState(
              this.getUIContext().getHostContext() as common.Context, true)
          })
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
            .animation({ curve: curves.springMotion(0.4, 0.86, 0.16) }))
        } else if (this.vocabularyStudyOpen) {
          VocabularyStudyPage({
            level: this.vocabularyStudyLevel,
            wordIds: this.vocabularyStudyWordIds,
            initialWordId: this.vocabularyStudyWordId,
            journey: this.currentJourney,
            journeyCompletedMask: this.journeyCompletedMask,
            onAsk: (context: AiInquiryContext) => this.openInquiry(context),
            onBack: () => this.closeVocabularyStudy(),
            onToneChange: (toneIndex: number) => this.vocabularySceneTone = toneIndex
          })
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 20 }))
            .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
            .animation({ curve: curves.springMotion(0.44, 0.84, 0.18) }))
        } else {
        HdsTabs({ barPosition: BarPosition.End, index: this.section, controller: this.tabsController }) {
          TabContent() {
            LearnPage({
              kanaKey: this.kanaKey,
              learnedWordCount: this.learnedWordCount,
              videoCount: this.videoCount,
              lastVideoTitle: this.lastVideoTitle,
              readingIndex: this.readingIndex,
              scenarioIndex: this.scenarioIndex,
              grammarId: this.grammarId,
              onScrollerReady: (scroller: Scroller) => this.bindTabScroller(AppSection.LEARN, scroller),
              onFloatingBarCompactChange: (compact: boolean) => this.setFloatingBarsCompact(compact),
              onOpenKana: () => this.selectSection(AppSection.KANA),
              onOpenVocabulary: () => this.selectSection(AppSection.VOCABULARY),
              onOpenExplore: (tab: number) => this.openExplore(tab),
              onOpenGrammar: () => this.openBasicsGrammar()
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.book_pages'), $r('sys.symbol.book_pages_fill')), '旅程'))

          TabContent() {
            BasicsPage({
              selectedTab: this.basicsTab,
              grammarId: this.grammarId,
              grammarOpen: this.activeGrammar !== undefined,
              initialKanaKey: this.kanaKey,
              onScrollerReady: (scroller: Scroller) => this.bindTabScroller(AppSection.KANA, scroller),
              onFloatingBarCompactChange: (compact: boolean) => this.setFloatingBarsCompact(compact),
              onTabChange: (index: number) => this.saveBasicsTab(index),
              onAsk: (context: AiInquiryContext) => this.openInquiry(context),
              onKanaChange: (key: string) => this.saveKanaKey(key),
              onOpenGrammar: (lesson: GrammarWork) => this.openGrammar(lesson)
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.character_square'), $r('sys.symbol.character_square_fill')), '基础'))

          TabContent() {
            VocabularyPage({
              searchActive: this.vocabularySearchOpen,
              onScrollerReady: (scroller: Scroller) => this.bindTabScroller(AppSection.VOCABULARY, scroller),
              onFloatingBarCompactChange: (compact: boolean) => this.setFloatingBarsCompact(compact),
              onAsk: (context: AiInquiryContext) => this.openInquiry(context),
              onStudy: (level: string, wordId: string, wordIds: string[]) =>
                this.openVocabularyStudy(level, wordId, wordIds),
              onSearchActiveChange: (active: boolean) => this.vocabularySearchOpen = active
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.translate_square'), $r('sys.symbol.translate_square_fill')), '词库'))

          TabContent() {
            ExplorePage({
              selectedTab: this.exploreTab,
              videoId: this.videoId,
              readingIndex: this.readingIndex,
              readingOpen: this.activeReading !== undefined,
              scenarioIndex: this.scenarioIndex,
              apiKeyConfigured: this.deepSeekApiKey.length > 0,
              onScrollerReady: (scroller: Scroller) => this.bindTabScroller(AppSection.EXPLORE, scroller),
              onFloatingBarCompactChange: (compact: boolean) => this.setFloatingBarsCompact(compact),
              onTabChange: (index: number) => this.saveExploreTab(index),
              onOpenVideo: (video: VideoItem) => this.openVideo(video),
              onOpenReading: (reading: ReadingWork, index: number) => this.openReading(reading, index),
              onScenarioChange: (index: number) => this.saveScenarioIndex(index),
              onStartScenario: (scenario: PracticeScenario) => this.startPractice(scenario),
              onAsk: (context: AiInquiryContext) => this.openInquiry(context)
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.compass_circle'), $r('sys.symbol.compass_circle_fill')), '探索'))

          TabContent() {
            MePage({
              journey: this.currentJourney,
              account: this.accountSnapshot,
              onScrollerReady: (scroller: Scroller) => this.bindTabScroller(AppSection.ME, scroller),
              onFloatingBarCompactChange: (compact: boolean) => this.setFloatingBarsCompact(compact),
              onSettings: () => this.settingsOpen = true,
              onAccountChange: (snapshot: HuaweiAccountSnapshot) => this.handleAccountChange(snapshot)
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.person'), $r('sys.symbol.person_fill')), '我的'))
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        .barMode(BarMode.Fixed)
        .scrollable(false)
        .animationDuration(MOTION_DURATION)
        .barOverlap(true)
        .barBackgroundColor(Color.Transparent)
        .blurStrategy(BlurStrategy.ADAPTIVE)
        .divider({ mode: DividerMode.NONE })
        .barFloatingStyle({
          barSideMargin: 16,
          barBottomMargin: FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomSafeInset(),
          gradientMask: {
            // The mask paints on top of the bar's material layer, so an opaque
            // color cancels the immersive effect entirely. HdsTabs defaults to
            // a translucent mask (#CCF1F3F5 light / #99000000 dark) for exactly
            // this reason; mirror that so the material stays visible. Keep the
            // mask near the bar's own height (56vp + 16vp) instead of reusing
            // the content inset, which covers far more of the material.
            maskColor: $r('app.color.tab_gradient_mask'),
            maskHeight: FLOATING_TAB_MASK_HEIGHT
          },
          adaptToHandedness: true,
          lightColor: $r('app.color.accent'),
          miniBar: undefined,
          systemMaterialEffect: bottomBarImmersiveMaterial(),
          thermoCtrl: true
        })
        .onChange((section: number) => {
          if (section !== this.section) {
            this.selectSection(section);
          }
        })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.985, y: 0.985 }))
          .animation({ curve: curves.springMotion(0.4, 0.88, 0.14) }))
        }
      }
      .width('100%')
      .height('100%')

      Column()
        .width(1)
        .height(1)
        .margin({ bottom: 88 })
        .bindPopup(this.inquiryPopupOpen, {
          builder: this.aiInquiryPopup,
          placement: Placement.Top,
          width: 336,
          popupColor: $r('app.color.surface_raised'),
          enableArrow: true,
          autoCancel: true,
          mask: false,
          focusable: true,
          radius: 24,
          shadow: ShadowStyle.OUTER_DEFAULT_MD,
          backgroundBlurStyle: BlurStyle.COMPONENT_REGULAR,
          keyboardAvoidMode: KeyboardAvoidMode.DEFAULT,
          onStateChange: (event) => {
            if (!event.isVisible) {
              this.finishInquiryDismissal();
            }
          }
        })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.kanaLookupOpen, this.kanaLookupSheet(), {
      height: SheetSize.LARGE,
      preferType: SheetType.BOTTOM,
      title: { title: '五十音图' },
      dragBar: true,
      showClose: true,
      blurStyle: BlurStyle.COMPONENT_REGULAR,
      backgroundColor: $r('app.color.surface_raised'),
      maskColor: '#52000000',
      onDisappear: () => this.kanaLookupOpen = false
    })
    .padding({
      left: this.activeReading === undefined && this.activeVideo === undefined &&
        this.activeGrammar === undefined ? this.leftSafeInset() : 0,
      right: this.activeReading === undefined && this.activeVideo === undefined &&
        this.activeGrammar === undefined ? this.rightSafeInset() : 0
    })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private aiInquiryPopup() {
    if (this.activeInquiry !== undefined) {
      Column() {
        ContextAiPanel({
          context: this.activeInquiry,
          apiKey: this.deepSeekApiKey,
          onClose: () => this.closeInquiry()
        })
      }
      .width('100%')
      .height(460)
      .borderRadius(24)
      .clip(true)
    }
  }

  @Builder
  private kanaLookupSheet() {
    KanaLookupSheet({
      query: this.kanaLookupQuery
    })
  }

  onBackPress(): boolean {
    if (this.inquiryPopupOpen) {
      this.closeInquiry();
      return true;
    }
    if (this.activeGrammar !== undefined) {
      this.closeGrammar();
      return true;
    }
    if (this.activeReading !== undefined) {
      this.closeReading();
      return true;
    }
    if (this.activeVideo !== undefined) {
      this.closeVideoPlayer();
      return true;
    }
    if (this.activeScenario !== undefined) {
      this.closePractice();
      return true;
    }
    if (this.settingsOpen) {
      this.settingsOpen = false;
      return true;
    }
    if (this.vocabularyStudyOpen) {
      this.closeVocabularyStudy();
      return true;
    }
    if (this.section === AppSection.VOCABULARY && this.vocabularySearchOpen) {
      this.vocabularySearchOpen = false;
      return true;
    }
    if (this.section !== AppSection.LEARN) {
      this.selectSection(AppSection.LEARN);
      return true;
    }
    return false;
  }
}
