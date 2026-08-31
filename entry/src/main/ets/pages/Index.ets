import { common } from '@kit.AbilityKit';
import { curves, window } from '@kit.ArkUI';
import {
  BlurStrategy,
  DividerMode,
  HdsBarLayoutMode,
  HdsBarStyle,
  HdsTabs,
  HdsTabsController,
  HdsTabsMiniBar
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import {
  CONTENT_MAX_WIDTH,
  FLOATING_TAB_BAR_BOTTOM_MARGIN,
  FLOATING_TAB_CONTENT_INSET,
  MOTION_DURATION
} from '../common/AppTheme';
import { preferredImmersiveMaterial } from '../common/ImmersiveMaterial';
import { AppSection, LearningJourney, MusicTrack, PracticeScenario, ReadingWork } from '../model/ContentModels';
import { AiInquiryContext } from '../model/DeepSeekModels';
import {
  emptyMusicPlaybackSnapshot,
  MusicPlaybackListener,
  MusicPlaybackSnapshot
} from '../model/MusicPlaybackModels';
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
import { MusicPlaybackService } from '../services/MusicPlaybackService';
import { VocabularyLearningStore } from '../services/VocabularyLearningStore';
import { ExplorePage } from '../views/pages/ExplorePage';
import { KanaPage } from '../views/pages/KanaPage';
import { LearnPage } from '../views/pages/LearnPage';
import { MePage } from '../views/pages/MePage';
import { MusicPlayerPage } from '../views/pages/MusicPlayerPage';
import { PracticeSessionPage } from '../views/pages/PracticeSessionPage';
import { ReadingPage } from '../views/pages/ReadingPage';
import { SettingsPage } from '../views/pages/SettingsPage';
import { VocabularyPage } from '../views/pages/VocabularyPage';
import { VocabularyStudyPage } from '../views/pages/VocabularyStudyPage';
import { ImmersiveBackdrop } from '../views/components/ImmersiveCanvas';
import { ContextAiPanel } from '../views/components/ContextAiPanel';
import { MusicMiniPlayer } from '../views/components/MusicMiniPlayer';

@Entry
@Component
struct Index {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  @State private section: number = AppSection.LEARN;
  @State private grammarIndex: number = 0;
  @State private deepSeekApiKey: string = '';
  @State private settingsOpen: boolean = false;
  @State private activeScenario: PracticeScenario | undefined = undefined;
  @State private activeReading: ReadingWork | undefined = undefined;
  @State private musicPlayerOpen: boolean = false;
  @State private musicTracks: MusicTrack[] = [];
  @State private musicPlayback: MusicPlaybackSnapshot = emptyMusicPlaybackSnapshot();
  @State private journeys: LearningJourney[] = [];
  @State private currentJourney: LearningJourney | undefined = undefined;
  @State private journeyStage: number = 0;
  @State private journeyCompletedMask: number = 0;
  @State private activeInquiry: AiInquiryContext | undefined = undefined;
  @State private inquiryPopupOpen: boolean = false;
  @State private vocabularyStudyOpen: boolean = false;
  @State private vocabularyStudyLevel: string = 'N5';
  @State private vocabularyStudyWordId: string = '';
  @State private vocabularyStudyWordIds: string[] = [];
  @State private vocabularySceneTone: number = -1;
  @State private vocabularySearchOpen: boolean = false;
  @State private kanaKey: string = 'あ';
  @State private exploreTab: number = 0;
  @State private musicIndex: number = -1;
  @State private readingIndex: number = -1;
  @State private scenarioIndex: number = -1;
  @State private learnedWordCount: number = 0;
  @State private floatingBarsVertical: boolean = true;
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
  private musicPlaybackListener: MusicPlaybackListener = (snapshot: MusicPlaybackSnapshot) => {
    this.musicPlayback = snapshot;
    if (snapshot.trackIndex >= 0) {
      this.musicIndex = snapshot.trackIndex;
    }
  };

  aboutToAppear(): void {
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    const storedSection: number = LearningPreferences.section(context);
    this.section = storedSection >= AppSection.LEARN && storedSection <= AppSection.ME ?
      storedSection : AppSection.LEARN;
    this.grammarIndex = LearningPreferences.grammarIndex(context);
    this.deepSeekApiKey = LearningPreferences.deepSeekApiKey(context);
    this.journeyStage = LearningPreferences.journeyStage(context);
    this.journeyCompletedMask = LearningPreferences.journeyCompletedMask(context);
    this.kanaKey = LearningPreferences.kanaKey(context);
    this.exploreTab = LearningPreferences.exploreTab(context);
    this.musicIndex = LearningPreferences.musicIndex(context);
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
    try {
      this.musicTracks = ContentRepository.loadMusicTracks(context);
    } catch (error) {
      this.musicTracks = [];
    }
    MusicPlaybackService.initialize(context, this.musicTracks);
    MusicPlaybackService.subscribe(this.musicPlaybackListener);
    this.initializeAccountAndSync(context);
  }

  aboutToDisappear(): void {
    MusicPlaybackService.unsubscribe(this.musicPlaybackListener);
  }

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
    this.grammarIndex = LearningPreferences.grammarIndex(context);
    this.journeyStage = LearningPreferences.journeyStage(context);
    this.journeyCompletedMask = LearningPreferences.journeyCompletedMask(context);
    this.kanaKey = LearningPreferences.kanaKey(context);
    this.musicIndex = LearningPreferences.musicIndex(context);
    MusicPlaybackService.initialize(context, this.musicTracks);
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
    this.floatingBarsVertical = true;
    this.section = section;
    LearningPreferences.saveSection(this.getUIContext().getHostContext() as common.Context, section);
  }

  private saveGrammarIndex(index: number): void {
    this.grammarIndex = index;
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    LearningPreferences.saveGrammarIndex(context, index);
    LearningSyncCoordinator.saveGrammarProgress(context, index);
  }

  private saveKanaKey(key: string): void {
    this.kanaKey = key;
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    LearningPreferences.saveKanaKey(context, key);
    LearningSyncCoordinator.saveKanaProgress(context, key);
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

  private saveMusicIndex(index: number): void {
    this.musicIndex = index;
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    LearningPreferences.saveMusicIndex(context, index);
    LearningSyncCoordinator.saveMusicProgress(context, index);
  }

  private openMusic(index: number, autoplay: boolean): void {
    if (index < 0 || index >= this.musicTracks.length) {
      return;
    }
    this.saveMusicIndex(index);
    this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.84, 0.18) }, () => {
      this.musicPlayerOpen = true;
    });
    if (autoplay) {
      MusicPlaybackService.playTrack(index);
    } else {
      MusicPlaybackService.prepareTrack(index);
    }
  }

  private closeMusicPlayer(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.38, 0.88, 0.16) }, () => {
      this.musicPlayerOpen = false;
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
    return Math.max(this.avoidAreas.navigationIndicator.bottomRect.height, this.avoidAreas.cutout.bottomRect.height,
      this.avoidAreas.statusBar.bottomRect.height);
  }

  private shellBottomInset(): number {
    if (this.activeReading !== undefined) {
      return 0;
    }
    const tabsVisible: boolean = this.activeScenario === undefined && !this.settingsOpen &&
      !this.vocabularyStudyOpen && this.activeReading === undefined && !this.musicPlayerOpen;
    return tabsVisible ? 0 : this.bottomSafeInset();
  }

  private miniPlayerVisible(): boolean {
    return !this.musicPlayerOpen && this.activeReading === undefined && this.activeScenario === undefined &&
      !this.settingsOpen && !this.vocabularyStudyOpen && this.musicPlayback.trackIndex >= 0 &&
      this.musicPlayback.trackIndex < this.musicTracks.length;
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
    this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.86, 0.16) }, () => {
      this.floatingBarsVertical = vertical;
    });
  }

  private musicMiniBarOptions(): HdsTabsMiniBar | undefined {
    if (!this.miniPlayerVisible()) {
      return undefined;
    }
    return {
      // HdsTabs invokes CustomBuilder from its native component context. Keep
      // the owning Index instance captured instead of passing an unbound
      // member builder, otherwise generated ArkUI code receives `this` as
      // undefined at runtime.
      miniBarBuilder: () => {
        this.musicMiniBar()
      },
      // In a vertical stack, letting the tab bar take expansion priority keeps
      // both rows visible. In a horizontal row, prioritizing the mini bar makes
      // the tab bar collapse to the selected icon, matching the system player.
      miniBarStyle: this.floatingBarsVertical ? HdsBarStyle.COLLAPSE : HdsBarStyle.EXPAND,
      barLayoutMode: this.floatingBarsVertical ? HdsBarLayoutMode.VERTICAL : HdsBarLayoutMode.HORIZONTAL,
      enableMiniBarBackground: true,
      enableMiniBarClip: true
    };
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
        canvasContent: () => {
          this.appShell()
        }
      })
    }
    .width('100%')
    .height('100%')
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
        if (this.musicPlayerOpen) {
          MusicPlayerPage({
            tracks: this.musicTracks,
            snapshot: this.musicPlayback,
            onBack: () => this.closeMusicPlayer(),
            onToggle: () => MusicPlaybackService.toggle(),
            onPrevious: () => MusicPlaybackService.previous(),
            onNext: () => MusicPlaybackService.next(),
            onSeek: (positionMs: number) => MusicPlaybackService.seek(positionMs),
            onAsk: (context: AiInquiryContext) => this.openInquiry(context)
          })
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 18 }))
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
          .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
            .animation({ curve: curves.springMotion(0.42, 0.82, 0.18) }))
        } else if (this.settingsOpen) {
          SettingsPage({
            initialApiKey: this.deepSeekApiKey,
            account: this.accountSnapshot,
            syncState: this.cloudSyncSnapshot,
            onBack: () => this.settingsOpen = false,
            onSave: (apiKey: string) => this.saveDeepSeekApiKey(apiKey),
            onSync: () => this.syncLearningState(
              this.getUIContext().getHostContext() as common.Context, true)
          })
          .width('100%')
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
            learnedGrammarIndex: this.grammarIndex,
            journeyCompletedMask: this.journeyCompletedMask,
            onAsk: (context: AiInquiryContext) => this.openInquiry(context),
            onBack: () => this.closeVocabularyStudy(),
            onToneChange: (toneIndex: number) => this.vocabularySceneTone = toneIndex
          })
          .width('100%')
          .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 20 }))
            .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
            .animation({ curve: curves.springMotion(0.44, 0.84, 0.18) }))
        } else {
        HdsTabs({ barPosition: BarPosition.End, index: this.section, controller: this.tabsController }) {
          TabContent() {
            LearnPage({
              savedLessonIndex: this.grammarIndex,
              kanaKey: this.kanaKey,
              learnedWordCount: this.learnedWordCount,
              musicIndex: this.musicIndex,
              readingIndex: this.readingIndex,
              scenarioIndex: this.scenarioIndex,
              onScrollerReady: (scroller: Scroller) => this.bindTabScroller(AppSection.LEARN, scroller),
              onFloatingBarCompactChange: (compact: boolean) => this.setFloatingBarsCompact(compact),
              onLessonChange: (index: number) => this.saveGrammarIndex(index),
              onOpenKana: () => this.selectSection(AppSection.KANA),
              onOpenVocabulary: () => this.selectSection(AppSection.VOCABULARY),
              onOpenExplore: (tab: number) => this.openExplore(tab),
              onAsk: (context: AiInquiryContext) => this.openInquiry(context)
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.book_pages'), $r('sys.symbol.book_pages_fill')), '旅程'))

          TabContent() {
            KanaPage({
              initialKanaKey: this.kanaKey,
              onScrollerReady: (scroller: Scroller) => this.bindTabScroller(AppSection.KANA, scroller),
              onFloatingBarCompactChange: (compact: boolean) => this.setFloatingBarsCompact(compact),
              onAsk: (context: AiInquiryContext) => this.openInquiry(context),
              onKanaChange: (key: string) => this.saveKanaKey(key)
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.character_square'), $r('sys.symbol.character_square_fill')), '五十音'))

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
              musicIndex: this.musicIndex,
              readingIndex: this.readingIndex,
              scenarioIndex: this.scenarioIndex,
              apiKeyConfigured: this.deepSeekApiKey.length > 0,
              onScrollerReady: (scroller: Scroller) => this.bindTabScroller(AppSection.EXPLORE, scroller),
              onFloatingBarCompactChange: (compact: boolean) => this.setFloatingBarsCompact(compact),
              onTabChange: (index: number) => this.saveExploreTab(index),
              onOpenMusic: (track: MusicTrack, index: number) => this.openMusic(index, true),
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
        .barMode(BarMode.Fixed)
        .scrollable(false)
        .animationDuration(MOTION_DURATION)
        .barOverlap(true)
        .barBackgroundColor(Color.Transparent)
        .blurStrategy(BlurStrategy.ADAPTIVE)
        .divider({ mode: DividerMode.NONE })
        .barFloatingStyle({
          barSideMargin: 16,
          barBottomMargin: FLOATING_TAB_BAR_BOTTOM_MARGIN,
          gradientMask: {
            maskColor: $r('app.color.surface'),
            maskHeight: FLOATING_TAB_CONTENT_INSET
          },
          adaptToHandedness: true,
          lightColor: $r('app.color.accent'),
          miniBar: this.musicMiniBarOptions(),
          systemMaterialEffect: preferredImmersiveMaterial(),
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
    .padding({
      bottom: this.shellBottomInset(),
      left: this.activeReading === undefined && !this.musicPlayerOpen ? this.leftSafeInset() : 0,
      right: this.activeReading === undefined && !this.musicPlayerOpen ? this.rightSafeInset() : 0
    })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private musicMiniBar() {
    MusicMiniPlayer({
      tracks: this.musicTracks,
      snapshot: this.musicPlayback,
      onOpen: () => this.openMusic(this.musicPlayback.trackIndex, false),
      onToggle: () => MusicPlaybackService.toggle(),
      onNext: () => MusicPlaybackService.next()
    })
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

  onBackPress(): boolean {
    if (this.inquiryPopupOpen) {
      this.closeInquiry();
      return true;
    }
    if (this.activeReading !== undefined) {
      this.closeReading();
      return true;
    }
    if (this.musicPlayerOpen) {
      this.closeMusicPlayer();
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
