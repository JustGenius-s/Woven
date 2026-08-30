import { common } from '@kit.AbilityKit';
import { BlurStrategy, DividerMode, HdsTabs } from '@kit.UIDesignKit';
import {
  FLOATING_TAB_BAR_BOTTOM_MARGIN,
  FLOATING_TAB_BAR_HEIGHT,
  FLOATING_TAB_CONTENT_INSET
} from '../common/AppTheme';
import { preferredImmersiveMaterial } from '../common/ImmersiveMaterial';
import { AppSection, PracticeScenario } from '../model/ContentModels';
import { LearningPreferences } from '../services/LearningPreferences';
import { KanaPage } from '../views/pages/KanaPage';
import { LearnPage } from '../views/pages/LearnPage';
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

  aboutToAppear(): void {
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    const storedSection: number = LearningPreferences.section(context);
    this.section = storedSection >= AppSection.LEARN && storedSection <= AppSection.PRACTICE ?
      storedSection : AppSection.LEARN;
    this.gatewayUrl = LearningPreferences.gatewayUrl(context);
    this.appToken = LearningPreferences.appToken(context);
    this.model = LearningPreferences.model(context);
    this.grammarIndex = LearningPreferences.grammarIndex(context);
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
    Stack() {
      if (this.activeScenario !== undefined) {
        PracticeSessionPage({
          scenario: this.activeScenario,
          gatewayUrl: this.gatewayUrl,
          appToken: this.appToken,
          model: this.model,
          onExit: () => this.activeScenario = undefined
        })
      } else if (this.settingsOpen) {
        SettingsPage({
          initialGatewayUrl: this.gatewayUrl,
          initialAppToken: this.appToken,
          initialModel: this.model,
          onClose: () => this.settingsOpen = false,
          onSave: (gatewayUrl: string, appToken: string, model: string) =>
            this.saveSettings(gatewayUrl, appToken, model)
        })
      } else {
        HdsTabs({ barPosition: BarPosition.End, index: this.section }) {
          TabContent() {
            LearnPage({
              gatewayUrl: this.gatewayUrl,
              appToken: this.appToken,
              model: this.model,
              savedLessonIndex: this.grammarIndex,
              onLessonChange: (index: number) => this.saveGrammarIndex(index),
              onSettings: () => this.settingsOpen = true,
              onPractice: () => this.selectSection(AppSection.PRACTICE)
            })
          }
          .tabBar(this.tabItem(AppSection.LEARN, $r('sys.symbol.bookmark'), '学习'))

          TabContent() {
            KanaPage({ onSettings: () => this.settingsOpen = true })
          }
          .tabBar(this.tabItem(AppSection.KANA, $r('sys.symbol.square_and_pencil'), '假名'))

          TabContent() {
            VocabularyPage({ onSettings: () => this.settingsOpen = true })
          }
          .tabBar(this.tabItem(AppSection.VOCABULARY, $r('sys.symbol.magnifyingglass'), '单词'))

          TabContent() {
            MaterialsPage({
              gatewayUrl: this.gatewayUrl,
              appToken: this.appToken,
              model: this.model,
              onSettings: () => this.settingsOpen = true
            })
          }
          .tabBar(this.tabItem(AppSection.MATERIALS, $r('sys.symbol.envelope'), '素材'))

          TabContent() {
            PracticePage({
              onSettings: () => this.settingsOpen = true,
              onStart: (scenario: PracticeScenario) => this.activeScenario = scenario
            })
          }
          .tabBar(this.tabItem(AppSection.PRACTICE, $r('sys.symbol.message'), '对练'))
        }
        .width('100%')
        .height('100%')
        .barMode(BarMode.Fixed)
        .barHeight(FLOATING_TAB_BAR_HEIGHT)
        .scrollable(false)
        .animationDuration(260)
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
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  onBackPress(): boolean {
    if (this.activeScenario !== undefined) {
      this.activeScenario = undefined;
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
