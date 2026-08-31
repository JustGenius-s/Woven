import { common } from '@kit.AbilityKit';
import { curves, window } from '@kit.ArkUI';
import { BlurStrategy, DividerMode, HdsTabs } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import {
  CONTENT_MAX_WIDTH,
  FLOATING_TAB_BAR_BOTTOM_MARGIN,
  FLOATING_TAB_CONTENT_INSET,
  MOTION_DURATION
} from '../common/AppTheme';
import { preferredImmersiveMaterial } from '../common/ImmersiveMaterial';
import { AppSection, LearningJourney, PracticeScenario } from '../model/ContentModels';
import { AiInquiryContext } from '../model/DeepSeekModels';
import { ContentRepository } from '../services/ContentRepository';
import { LearningPreferences } from '../services/LearningPreferences';
import { KanaPage } from '../views/pages/KanaPage';
import { LearnPage } from '../views/pages/LearnPage';
import { JourneyPage } from '../views/pages/JourneyPage';
import { MePage } from '../views/pages/MePage';
import { PracticePage } from '../views/pages/PracticePage';
import { PracticeSessionPage } from '../views/pages/PracticeSessionPage';
import { SettingsPage } from '../views/pages/SettingsPage';
import { VocabularyPage } from '../views/pages/VocabularyPage';
import { ImmersiveBackdrop } from '../views/components/ImmersiveCanvas';
import { ContextAiPanel } from '../views/components/ContextAiPanel';

@Entry
@Component
struct Index {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  @State private section: number = AppSection.LEARN;
  @State private grammarIndex: number = 0;
  @State private deepSeekApiKey: string = '';
  @State private settingsOpen: boolean = false;
  @State private activeScenario: PracticeScenario | undefined = undefined;
  @State private journeys: LearningJourney[] = [];
  @State private currentJourney: LearningJourney | undefined = undefined;
  @State private journeyOpen: boolean = false;
  @State private journeyStage: number = 0;
  @State private journeyCompletedMask: number = 0;
  @State private showHomeGuide: boolean = false;
  @State private activeInquiry: AiInquiryContext | undefined = undefined;
  @State private inquiryPopupOpen: boolean = false;

  aboutToAppear(): void {
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    const storedSection: number = LearningPreferences.section(context);
    this.section = storedSection >= AppSection.LEARN && storedSection <= AppSection.ME ?
      storedSection : AppSection.LEARN;
    this.grammarIndex = LearningPreferences.grammarIndex(context);
    this.deepSeekApiKey = LearningPreferences.deepSeekApiKey(context);
    this.journeyStage = LearningPreferences.journeyStage(context);
    this.journeyCompletedMask = LearningPreferences.journeyCompletedMask(context);
    this.showHomeGuide = LearningPreferences.shouldShowHomeGuide(context);
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
  }

  private selectSection(section: number): void {
    this.section = section;
    LearningPreferences.saveSection(this.getUIContext().getHostContext() as common.Context, section);
  }

  private saveGrammarIndex(index: number): void {
    this.grammarIndex = index;
    LearningPreferences.saveGrammarIndex(this.getUIContext().getHostContext() as common.Context, index);
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

  private finishInquiryDismissal(): void {
    this.inquiryPopupOpen = false;
    this.activeInquiry = undefined;
  }

  private openJourney(journey: LearningJourney): void {
    const changed: boolean = this.currentJourney?.id !== journey.id;
    this.getUIContext().animateTo({ curve: curves.springMotion(0.42, 0.84, 0.18) }, () => {
      if (changed) {
        this.currentJourney = journey;
        this.journeyStage = 0;
        this.journeyCompletedMask = 0;
      }
      this.journeyOpen = true;
    });
    if (changed) {
      LearningPreferences.saveJourneyProgress(this.getUIContext().getHostContext() as common.Context,
        journey.id, 0, 0);
    }
  }

  private closeJourney(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.38, 0.88, 0.16) }, () => {
      this.journeyOpen = false;
    });
  }

  private saveJourneyProgress(journeyId: string, stage: number, completedMask: number): void {
    this.journeyStage = stage;
    this.journeyCompletedMask = completedMask;
    LearningPreferences.saveJourneyProgress(this.getUIContext().getHostContext() as common.Context,
      journeyId, stage, completedMask);
  }

  private dismissHomeGuide(): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.38, 0.88, 0.16) }, () => {
      this.showHomeGuide = false;
    });
    LearningPreferences.saveHomeGuideSeen(this.getUIContext().getHostContext() as common.Context);
  }

  private topSafeInset(): number {
    return Math.max(this.avoidAreas.statusBar.topRect.height, this.avoidAreas.cutout.topRect.height,
      this.avoidAreas.navigationIndicator.topRect.height);
  }

  private bottomSafeInset(): number {
    return Math.max(this.avoidAreas.navigationIndicator.bottomRect.height, this.avoidAreas.cutout.bottomRect.height,
      this.avoidAreas.statusBar.bottomRect.height);
  }

  private shellBottomInset(): number {
    const tabsVisible: boolean = this.activeScenario === undefined && !this.settingsOpen &&
      (!this.journeyOpen || this.currentJourney === undefined);
    return tabsVisible ? 0 : this.bottomSafeInset();
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
        canvasContent: () => {
          this.appShell()
        }
      })
    }
    .width('100%')
    .height('100%')
    .background($r('app.color.surface'))
  }

  @Builder
  private appShell() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.activeScenario !== undefined) {
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
          onBack: () => this.settingsOpen = false,
          onSave: (apiKey: string) => this.saveDeepSeekApiKey(apiKey)
        })
        .width('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
          .animation({ curve: curves.springMotion(0.4, 0.86, 0.16) }))
      } else if (this.journeyOpen && this.currentJourney !== undefined) {
        JourneyPage({
          journey: this.currentJourney,
          initialStage: this.journeyStage,
          initialCompletedMask: this.journeyCompletedMask,
          onAsk: (context: AiInquiryContext) => this.openInquiry(context),
          onBack: () => this.closeJourney(),
          onProgress: (journeyId: string, stage: number, completedMask: number) =>
            this.saveJourneyProgress(journeyId, stage, completedMask)
        })
        .width('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 22 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: curves.springMotion(0.46, 0.84, 0.18) }))
      } else {
        HdsTabs({ barPosition: BarPosition.End, index: this.section }) {
          TabContent() {
            LearnPage({
              savedLessonIndex: this.grammarIndex,
              journeys: this.journeys,
              currentJourney: this.currentJourney,
              journeyStage: this.journeyStage,
              journeyCompletedMask: this.journeyCompletedMask,
              showHomeGuide: this.showHomeGuide,
              onLessonChange: (index: number) => this.saveGrammarIndex(index),
              onJourney: (journey: LearningJourney) => this.openJourney(journey),
              onAsk: (context: AiInquiryContext) => this.openInquiry(context),
              onDismissHomeGuide: () => this.dismissHomeGuide()
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.book_pages'), $r('sys.symbol.book_pages_fill')), '旅程'))

          TabContent() {
            KanaPage({
              journey: this.currentJourney,
              onAsk: (context: AiInquiryContext) => this.openInquiry(context)
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.character_square'), $r('sys.symbol.character_square_fill')), '假名'))

          TabContent() {
            VocabularyPage({
              journey: this.currentJourney,
              onAsk: (context: AiInquiryContext) => this.openInquiry(context)
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.translate_square'), $r('sys.symbol.translate_square_fill')), '词库'))

          TabContent() {
            PracticePage({
              journey: this.currentJourney,
              apiKeyConfigured: this.deepSeekApiKey.length > 0,
              onStart: (scenario: PracticeScenario) => this.startPractice(scenario)
            })
          }
          .tabBar(BottomTabBarStyle.of(this.tabSymbol(
            $r('sys.symbol.message'), $r('sys.symbol.message_fill')), '对练'))

          TabContent() {
            MePage({
              journey: this.currentJourney,
              onSettings: () => this.settingsOpen = true
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
      top: this.topSafeInset(),
      bottom: this.shellBottomInset(),
      left: this.leftSafeInset(),
      right: this.rightSafeInset()
    })
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

  onBackPress(): boolean {
    if (this.inquiryPopupOpen) {
      this.closeInquiry();
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
    if (this.journeyOpen) {
      this.closeJourney();
      return true;
    }
    if (this.section !== AppSection.LEARN) {
      this.selectSection(AppSection.LEARN);
      return true;
    }
    return false;
  }
}
