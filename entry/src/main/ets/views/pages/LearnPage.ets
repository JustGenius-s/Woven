import { common } from '@kit.AbilityKit';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { Dialogue, DialogueLine, GrammarIndexEntry, LearningCatalog } from '../../model/ContentModels';
import { ContentRepository } from '../../services/ContentRepository';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { contentLightEffect, ImmersivePlane, planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';
import { GrammarPage } from './GrammarPage';

@Component
export struct LearnPage {
  gatewayUrl: string = '';
  appToken: string = '';
  model: string = '';
  savedLessonIndex: number = 0;
  onLessonChange: (index: number) => void = (index: number) => {};
  onSettings: () => void = () => {};
  onPractice: () => void = () => {};

  @State private mode: number = 0;
  @State private grammarIndex: GrammarIndexEntry[] = [];
  @State private catalog: LearningCatalog | undefined = undefined;
  @State private dialogueIndex: number = 0;
  @State private loadError: string = '';

  aboutToAppear(): void {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.grammarIndex = ContentRepository.loadGrammarIndex(context);
      this.catalog = ContentRepository.loadCatalog(context);
      this.loadError = '';
    } catch (error) {
      this.loadError = '课程资源读取失败，请重新安装应用';
    }
  }

  build() {
    if (this.mode === 1) {
      GrammarPage({
        entries: this.grammarIndex,
        initialIndex: this.savedLessonIndex,
        gatewayUrl: this.gatewayUrl,
        appToken: this.appToken,
        model: this.model,
        onIndexChange: this.onLessonChange,
        onBack: () => this.mode = 0
      })
    } else if (this.mode === 2) {
      this.dialogues()
    } else {
      this.home()
    }
  }

  @Builder
  private home() {
    Column() {
      PageChrome({ title: '今日の一歩', onSettings: this.onSettings })
      if (this.loadError.length > 0) {
        Column({ space: 12 }) {
          Text('课程没有加载出来')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.loadError)
            .fontSize(15)
            .fontColor($r('app.color.danger'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 18 }) {
            Row() {
              Column({ space: 4 }) {
                Text('読む').fontSize(10).fontColor($r('app.color.accent')).letterSpacing(1)
                Text('聴く').fontSize(10).fontColor($r('app.color.accent')).letterSpacing(1)
                Text('話す').fontSize(10).fontColor($r('app.color.accent')).letterSpacing(1)
              }
              .width(50)
              .alignItems(HorizontalAlign.Start)
              Text('一歩')
                .fontSize(78)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .letterSpacing(-3)
              Blank()
              Text('先理解\n再开口')
                .fontSize(14)
                .fontColor($r('app.color.ink_muted'))
                .lineHeight(23)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .height(126)
            .alignItems(VerticalAlign.Center)
            .visualEffect(contentLightEffect())

            if (this.grammarIndex.length > 0) {
              ImmersivePlane({
                planeStrong: true,
                interactive: true,
                planeContent: () => {
                  this.continueLesson(
                    this.grammarIndex[Math.min(this.savedLessonIndex, this.grammarIndex.length - 1)])
                }
              })
            }

            Row({ space: 14 }) {
              this.featurePortal('会話', '日常对话', () => this.mode = 2)
              this.featurePortal('AI', '场景对练', this.onPractice)
            }
            .width('100%')
            Column()
              .height(FLOATING_TAB_CONTENT_INSET)
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private continueLesson(lesson: GrammarIndexEntry) {
    Column({ space: 20 }) {
      Row() {
        Text('继续语法')
          .fontSize(13)
          .fontColor($r('app.color.accent'))
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`${lesson.level} · ${lesson.order.toString().padStart(2, '0')}`)
          .fontSize(12)
          .fontColor($r('app.color.ink_muted'))
      }
      Text(lesson.title)
        .width('100%')
        .fontSize(27)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .lineHeight(36)
        .maxLines(3)
      Text(lesson.summary)
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(24)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      ImmersiveAction({
        label: '继续学习',
        actionAccessibilityText: '继续当前语法课',
        icon: $r('sys.symbol.arrow_right'),
        emphasized: true,
        onAction: () => this.mode = 1
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 24, right: 22, top: 24, bottom: 24 })
    .onClick(() => this.mode = 1)
  }

  @Builder
  private featurePortal(kicker: string, title: string, onSelect: () => void) {
    Column() {
      Text(kicker)
        .width('100%')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
        .letterSpacing(1.2)
      Text(title)
        .width('100%')
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .lineHeight(31)
      Blank()
      Row() {
        Blank()
          ImmersiveAction({
            actionAccessibilityText: `进入${title}`,
            icon: $r('sys.symbol.arrow_right'),
            actionSize: 40,
            onAction: onSelect
          })
      }
      .width('100%')
    }
    .width('48%')
    .height(166)
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .borderRadius(24)
    .clip(true)
    .backgroundEffect({ radius: 26, color: $r('app.color.immersive_plane'), saturation: 1.08 })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .shadow({ radius: 24, color: '#12000000', offsetY: 9 })
    .visualEffect(planeLightEffect())
    .onClick(onSelect)
  }

  @Builder
  private dialogues() {
    Column() {
      ImmersiveBackChrome({ title: '日常对话', onBack: () => this.mode = 0 })

      if (this.catalog !== undefined) {
        Swiper() {
          ForEach(this.catalog?.dialogues ?? [], (dialogue: Dialogue) => {
            this.dialoguePage(dialogue)
          }, (dialogue: Dialogue) => dialogue.id)
        }
        .index(this.dialogueIndex)
        .indicator(false)
        .loop(false)
        .duration(280)
        .layoutWeight(1)
        .onChange((index: number) => this.dialogueIndex = index)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private dialoguePage(dialogue: Dialogue) {
    List({ space: 0 }) {
      ListItem() {
        Column({ space: 10 }) {
          Text(dialogue.setting)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .letterSpacing(1.3)
          Text(dialogue.title)
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(dialogue.goal)
            .fontSize(14)
            .lineHeight(23)
            .fontColor($r('app.color.ink_muted'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(24)
        .margin({ top: 16, bottom: 26 })
        .borderRadius(28)
        .clip(true)
        .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())
      }
      ForEach(dialogue.lines, (line: DialogueLine, index: number) => {
        ListItem() {
          Row({ space: 10 }) {
            if (line.learner === true) {
              Blank()
            }
            Text((index + 1).toString().padStart(2, '0'))
              .fontSize(11)
              .fontColor(line.learner === true ? $r('app.color.accent') : $r('app.color.ink_muted'))
              .opacity(0.62)
              .alignSelf(ItemAlign.Start)
            Column({ space: 8 }) {
              Text(line.speaker)
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(line.learner === true ? $r('app.color.accent') : $r('app.color.ink_muted'))
                .letterSpacing(0.8)
              Text(line.text)
                .width('100%')
                .fontSize(line.learner === true ? 22 : 27)
                .fontWeight(line.learner === true ? FontWeight.Medium : FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .lineHeight(line.learner === true ? 33 : 38)
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
              Text(line.reading)
                .width('100%')
                .fontSize(13)
                .fontColor($r('app.color.ink_muted'))
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
              Text(line.meaning)
                .width('100%')
                .fontSize(13)
                .fontColor($r('app.color.ink_muted'))
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
            }
            .width(line.learner === true ? '78%' : '90%')
            .alignItems(line.learner === true ? HorizontalAlign.End : HorizontalAlign.Start)
            if (line.learner !== true) {
              Blank()
            }
          }
          .width('100%')
          .padding({ top: 24, bottom: 24 })
          .visualEffect(contentLightEffect())
        }
      }, (line: DialogueLine, index: number) => `${dialogue.id}-${index}`)
      ListItem() {
        Column()
          .height(FLOATING_TAB_CONTENT_INSET)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 28, right: 28 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
