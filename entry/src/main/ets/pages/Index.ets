import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { BlurStrategy, DividerMode, HdsTabs } from '@kit.UIDesignKit';
import {
  CONTENT_MAX_WIDTH,
  FLOATING_TAB_BAR_BOTTOM_MARGIN,
  FLOATING_TAB_BAR_HEIGHT,
  FLOATING_TAB_CONTENT_INSET,
  MOTION_DURATION
} from '../common/AppTheme';
import { preferredImmersiveMaterial } from '../common/ImmersiveMaterial';
import { AppSection, LearningJourney, PracticeScenario } from '../model/ContentModels';
import { ContentRepository } from '../services/ContentRepository';
import { LearningPreferences } from '../services/LearningPreferences';
import { KanaPage } from '../views/pages/KanaPage';
import { LearnPage } from '../views/pages/LearnPage';
import { JourneyPage } from '../views/pages/JourneyPage';
import { MaterialsPage } from '../views/pages/MaterialsPage';
import { PracticePage } from '../views/pages/PracticePage';
import { PracticeSessionPage } from '../views/pages/PracticeSessionPage';
import { SettingsPage } from '../views/pages/SettingsPage';
import { VocabularyPage } from '../views/pages/VocabularyPage';
import { ImmersiveBackdrop } from '../views/components/ImmersiveCanvas';

@Entry
@Component
struct Index {
  @State private section: number = AppSection.LEARN;
  @State private settingsOpen: boolean = false;
  @State private gatewayUrl: string = '';
  @State private appToken: string = '';
  @State private model: string = '';
  @State private grammarIndex: number = 0;
  @State private activeScenario: PracticeScenario | undefined = undefined;
  @State private journeys: LearningJourney[] = [];
  @State private currentJourney: LearningJourney | undefined = undefined;
  @State private journeyOpen: boolean = false;
  @State private journeyStage: number = 0;
  @State private journeyCompletedMask: number = 0;

  aboutToAppear(): void {
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    const storedSection: number = LearningPreferences.section(context);
    this.section = storedSection >= AppSection.LEARN && storedSection <= AppSection.PRACTICE ?
      storedSection : AppSection.LEARN;
    this.gatewayUrl = LearningPreferences.gatewayUrl(context);
    this.appToken = LearningPreferences.appToken(context);
    this.model = LearningPreferences.model(context);
    this.grammarIndex = LearningPreferences.grammarIndex(context);
    this.journeyStage = LearningPreferences.journeyStage(context);
    this.journeyCompletedMask = LearningPreferences.journeyCompletedMask(context);
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

  private saveSettings(gatewayUrl: string, appToken: string, model: string): void {
    this.gatewayUrl = gatewayUrl;
    this.appToken = appToken;
    this.model = model;
    LearningPreferences.saveAiSettings(this.getUIContext().getHostContext() as common.Context,
      gatewayUrl, appToken, model);
    this.settingsOpen = false;
  }

  private saveGrammarIndex(index: number): void {
    this.grammarIndex = index;
    LearningPreferences.saveGrammarIndex(this.getUIContext().getHostContext() as common.Context, index);
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

  private saveJourneyProgress(journeyId: string, stage: number, completedMask: number): void {
    this.journeyStage = stage;
    this.journeyCompletedMask = completedMask;
    LearningPreferences.saveJourneyProgress(this.getUIContext().getHostContext() as common.Context,
      journeyId, stage, completedMask);
  }

  @Builder
  private tabItem(section: AppSection, symbol: Resource, label: string) {
    Column({ space: 3 }) {
      SymbolGlyph(symbol)
        .fontSize(20)
        .fontColor([this.section === section ? $r('app.color.accent') : $r('app.color.ink_muted')])
      Text(label)
        .fontSize(10)
        .fontWeight(this.section === section ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.section === section ? $r('app.color.ink') : $r('app.color.ink_muted'))
    }
    .width('100%')
    .height(54)
    .justifyContent(FlexAlign.Center)
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
  }

  @Builder
  private appShell() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.activeScenario !== undefined) {
        PracticeSessionPage({
          scenario: this.activeScenario,
          gatewayUrl: this.gatewayUrl,
          appToken: this.appToken,
          model: this.model,
          onExit: () => this.closePractice()
        })
        .width('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ curve: curves.springMotion(0.42, 0.82, 0.18) }))
      } else if (this.journeyOpen && this.currentJourney !== undefined) {
        JourneyPage({
          journey: this.currentJourney,
          initialStage: this.journeyStage,
          initialCompletedMask: this.journeyCompletedMask,
          gatewayUrl: this.gatewayUrl,
          appToken: this.appToken,
          model: this.model,
          onBack: () => this.closeJourney(),
          onProgress: (journeyId: string, stage: number, completedMask: number) =>
            this.saveJourneyProgress(journeyId, stage, completedMask),
          onStartPractice: (scenario: PracticeScenario) => this.startPractice(scenario)
        })
        .width('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 22 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: curves.springMotion(0.46, 0.84, 0.18) }))
      } else if (this.settingsOpen) {
        SettingsPage({
          initialGatewayUrl: this.gatewayUrl,
          initialAppToken: this.appToken,
          initialModel: this.model,
          onClose: () => this.settingsOpen = false,
          onSave: (gatewayUrl: string, appToken: string, model: string) =>
            this.saveSettings(gatewayUrl, appToken, model)
        })
        .width('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
          .animation({ curve: curves.springMotion(0.4, 0.86, 0.16) }))
      } else {
        HdsTabs({ barPosition: BarPosition.End, index: this.section }) {
          TabContent() {
            LearnPage({
              gatewayUrl: this.gatewayUrl,
              appToken: this.appToken,
              model: this.model,
              savedLessonIndex: this.grammarIndex,
              journeys: this.journeys,
              currentJourney: this.currentJourney,
              journeyStage: this.journeyStage,
              journeyCompletedMask: this.journeyCompletedMask,
              onLessonChange: (index: number) => this.saveGrammarIndex(index),
              onJourney: (journey: LearningJourney) => this.openJourney(journey),
              onSettings: () => this.settingsOpen = true,
              onPractice: () => this.selectSection(AppSection.PRACTICE)
            })
          }
          .tabBar(this.tabItem(AppSection.LEARN, $r('sys.symbol.bookmark'), '旅程'))

          TabContent() {
            KanaPage({ journey: this.currentJourney, onSettings: () => this.settingsOpen = true })
          }
          .tabBar(this.tabItem(AppSection.KANA, $r('sys.symbol.square_and_pencil'), '假名'))

          TabContent() {
            VocabularyPage({ journey: this.currentJourney, onSettings: () => this.settingsOpen = true })
          }
          .tabBar(this.tabItem(AppSection.VOCABULARY, $r('sys.symbol.magnifyingglass'), '词库'))

          TabContent() {
            MaterialsPage({
              gatewayUrl: this.gatewayUrl,
              appToken: this.appToken,
              model: this.model,
              onSettings: () => this.settingsOpen = true
            })
          }
          .tabBar(this.tabItem(AppSection.MATERIALS, $r('sys.symbol.envelope'), '输入'))

          TabContent() {
            PracticePage({
              journey: this.currentJourney,
              onSettings: () => this.settingsOpen = true,
              onStart: (scenario: PracticeScenario) => this.startPractice(scenario)
            })
          }
          .tabBar(this.tabItem(AppSection.PRACTICE, $r('sys.symbol.message'), '对练'))
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
        .barMode(BarMode.Fixed)
        .barHeight(FLOATING_TAB_BAR_HEIGHT)
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
          thermoCtrl: true,
          barOpacity: 0.94
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
    .backgroundColor(Color.Transparent)
  }

  onBackPress(): boolean {
    if (this.activeScenario !== undefined) {
      this.closePractice();
      return true;
    }
    if (this.journeyOpen) {
      this.closeJourney();
      return true;
    }
    if (this.settingsOpen) {
      this.settingsOpen = false;
      return true;
    }
    if (this.section !== AppSection.LEARN) {
      this.selectSection(AppSection.LEARN);
      return true;
    }
    return false;
  }
}
