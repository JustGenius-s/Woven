import { common } from '@kit.AbilityKit';
import { LearningCatalog, PracticeScenario } from '../../model/ContentModels';
import { ContentRepository } from '../../services/ContentRepository';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

@Component
export struct PracticePage {
  onSettings: () => void = () => {};
  onStart: (scenario: PracticeScenario) => void = (scenario: PracticeScenario) => {};

  @State private catalog: LearningCatalog | undefined = undefined;
  @State private error: string = '';
  @State private scenarioIndex: number = 0;

  aboutToAppear(): void {
    try {
      this.catalog = ContentRepository.loadCatalog(
        this.getUIContext().getHostContext() as common.Context);
      this.error = '';
    } catch (error) {
      this.error = '对练场景没有正确载入';
    }
  }

  build() {
    Column() {
      PageChrome({ title: '对练', onSettings: this.onSettings })
      if (this.error.length > 0) {
        Text(this.error)
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
      } else {
        Column() {
          Swiper() {
            ForEach(this.catalog?.practiceScenarios ?? [], (scenario: PracticeScenario, index: number) => {
              this.scenarioStage(scenario, index)
            }, (scenario: PracticeScenario) => scenario.id)
          }
          .index(this.scenarioIndex)
          .indicator(false)
          .loop(false)
          .duration(320)
          .layoutWeight(1)
          .onChange((index: number) => this.scenarioIndex = index)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private scenarioStage(scenario: PracticeScenario, index: number) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Text((index + 1).toString().padStart(2, '0'))
        .fontSize(132)
        .fontWeight(FontWeight.Lighter)
        .fontColor($r('app.color.accent'))
        .opacity(0.14)
        .position({ x: 18, y: 10 })

      Column({ space: 18 }) {
        Row() {
          Text(scenario.level)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .letterSpacing(1.2)
          Blank()
          Text(scenario.setting)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
        }
        Text(scenario.title)
          .width('100%')
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .lineHeight(52)
        Text(`${scenario.learnerRole}  ×  ${scenario.aiRole}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
        Text(scenario.goal)
          .width('100%')
          .fontSize(16)
          .lineHeight(27)
          .fontColor($r('app.color.ink_muted'))
        Row() {
          Blank()
          ImmersiveAction({
            label: '开始',
            actionAccessibilityText: `开始${scenario.title}`,
            icon: $r('sys.symbol.arrow_right'),
            actionSize: 48,
            emphasized: true,
            onAction: () => this.onStart(scenario)
          })
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(26)
    }
    .width('100%')
    .height('82%')
    .margin({ left: 18, right: 18, top: 10, bottom: 64 })
    .borderRadius(34)
    .clip(true)
    .backgroundEffect({ radius: 38, color: $r('app.color.immersive_plane_strong'), saturation: 1.1 })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .shadow({ radius: 28, color: '#16000000', offsetY: 12 })
    .visualEffect(planeLightEffect())
  }
}
