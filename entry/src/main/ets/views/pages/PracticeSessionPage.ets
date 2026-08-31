import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DeepSeekMessage, PracticeMessage } from '../../model/DeepSeekModels';
import { PracticeScenario } from '../../model/ContentModels';
import { DeepSeekClient } from '../../services/DeepSeekClient';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';

const MAX_CONTEXT_MESSAGES: number = 16;
const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'WovenPractice';
const EMPTY_SCENARIO: PracticeScenario = {
  id: '',
  title: '',
  setting: '',
  learnerRole: '',
  aiRole: '',
  level: '入门',
  goal: '',
  openingHint: ''
};

@Component
export struct PracticeSessionPage {
  scenario: PracticeScenario = EMPTY_SCENARIO;
  apiKey: string = '';
  onExit: () => void = () => {};

  @State private messages: PracticeMessage[] = [];
  @State private draft: string = '';
  @State private generating: boolean = false;
  @State private status: string = '';
  private history: DeepSeekMessage[] = [];
  private client?: DeepSeekClient;
  private activeAssistantId: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'Session appeared scenario=%{public}s keyConfigured=%{public}s',
      this.scenario.id, this.apiKey.trim().length > 0 ? 'true' : 'false');
    setTimeout(() => this.begin(), 180);
  }

  aboutToDisappear(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Session disappeared scenario=%{public}s generating=%{public}s',
      this.scenario.id, this.generating ? 'true' : 'false');
    this.client?.cancel();
  }

  private begin(): void {
    if (this.messages.length > 0 || this.generating) {
      return;
    }
    this.history = [{
      role: 'user',
      content: '场景现在开始。请以你的角色先自然开口，不要说明规则。'
    }];
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Opening request scenario=%{public}s', this.scenario.id);
    this.request();
  }

  private send(): void {
    const value: string = this.draft.trim();
    if (value.length === 0 || this.generating) {
      return;
    }
    this.draft = '';
    this.status = '';
    this.appendMessage('user', value);
    this.history.push({ role: 'user', content: value });
    hilog.info(LOG_DOMAIN, LOG_TAG, 'User turn scenario=%{public}s chars=%{public}d',
      this.scenario.id, value.length);
    this.request();
  }

  private retry(): void {
    if (!this.generating) {
      this.status = '';
      this.request();
    }
  }

  private stop(): void {
    if (!this.generating) {
      return;
    }
    this.client?.cancel();
    this.generating = false;
    this.status = '已停止生成，可以继续输入。';
    this.removeIfEmpty(this.activeAssistantId);
    this.activeAssistantId = '';
  }

  private request(): void {
    if (this.generating) {
      return;
    }
    this.client = new DeepSeekClient(this.apiKey);
    this.generating = true;
    this.status = '';
    const assistantId: string = this.appendMessage('assistant', '');
    this.activeAssistantId = assistantId;
    this.client.complete(this.contextMessages()).then((generated: string) => {
      this.generating = false;
      this.activeAssistantId = '';
      this.appendDelta(assistantId, generated);
      this.history.push({ role: 'assistant', content: generated });
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Assistant turn rendered scenario=%{public}s chars=%{public}d',
        this.scenario.id, generated.length);
      this.scrollToLatest();
    }).catch((error: Error) => {
      if (DeepSeekClient.isCancelled(error)) {
        return;
      }
      this.generating = false;
      this.activeAssistantId = '';
      this.status = error.message;
      this.removeIfEmpty(assistantId);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Request surfaced to UI scenario=%{public}s', this.scenario.id);
      showImmersiveNotice(this.getUIContext(), '场景互动暂时中断', error.message);
    });
  }

  private contextMessages(): DeepSeekMessage[] {
    const messages: DeepSeekMessage[] = [{ role: 'system', content: this.instructions() }];
    const start: number = Math.max(0, this.history.length - MAX_CONTEXT_MESSAGES);
    for (let index: number = start; index < this.history.length; index++) {
      messages.push(this.history[index]);
    }
    return messages;
  }

  private instructions(): string {
    return `你正在和日语学习者进行角色扮演。场景：${this.scenario.setting}。你扮演：${this.scenario.aiRole}。学习者扮演：${this.scenario.learnerRole}。难度：${this.scenario.level}。练习目标：${this.scenario.goal}。参考开场：${this.scenario.openingHint}。主要使用自然、简短的日语，每次只说一到两句，保持角色并给学习者回应空间。不要输出标题、列表或 Markdown。只有当学习者的日语明显影响理解时，才在日语回应后另起一行给出一句简短中文提示，格式为“自然表达：……”。`;
  }

  private appendMessage(role: string, text: string): string {
    const id: string = `${role}-${Date.now()}-${this.messages.length}`;
    this.messages = this.messages.concat([{ id: id, role: role, text: text, revision: 0 }]);
    this.scrollToLatest();
    return id;
  }

  private appendDelta(id: string, delta: string): void {
    const next: PracticeMessage[] = this.messages.slice();
    let updated: boolean = false;
    let revision: number = 0;
    for (let index: number = 0; index < next.length; index++) {
      if (next[index].id === id) {
        revision = next[index].revision + 1;
        next[index] = {
          id: next[index].id,
          role: next[index].role,
          text: next[index].text + delta,
          revision: revision
        };
        updated = true;
        break;
      }
    }
    this.messages = next;
    hilog.info(LOG_DOMAIN, LOG_TAG,
      'Message state updated found=%{public}s chars=%{public}d revision=%{public}d',
      updated ? 'true' : 'false', delta.length, revision);
    this.scrollToLatest();
  }

  private removeIfEmpty(id: string): void {
    const next: PracticeMessage[] = [];
    for (let index: number = 0; index < this.messages.length; index++) {
      if (this.messages[index].id !== id || this.messages[index].text.length > 0) {
        next.push(this.messages[index]);
      }
    }
    this.messages = next;
  }

  private scrollToLatest(): void {
    setTimeout(() => {
      if (this.messages.length > 0) {
        this.scroller.scrollToIndex(this.messages.length, true, ScrollAlign.END);
      }
    }, 30);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        ImmersiveBackChrome({
          title: this.scenario.title,
          subtitle: this.scenario.setting,
          closeIcon: true,
          onBack: this.onExit
        })

        List({ space: 0, scroller: this.scroller }) {
          ForEach(this.messages, (message: PracticeMessage) => {
            ListItem() {
              Row() {
                if (message.role === 'user') {
                  Blank()
                }
                Column({ space: 9 }) {
                  Text(message.role === 'user' ? 'あなた' : this.scenario.aiRole)
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(message.role === 'user' ? $r('app.color.accent') : $r('app.color.ink_muted'))
                    .letterSpacing(1)
                  if (message.text.length > 0) {
                    Text(message.text)
                      .width('100%')
                      .fontSize(message.role === 'user' ? 22 : 27)
                      .fontWeight(message.role === 'user' ? FontWeight.Medium : FontWeight.Bold)
                      .fontColor($r('app.color.ink'))
                      .lineHeight(message.role === 'user' ? 33 : 39)
                      .textAlign(message.role === 'user' ? TextAlign.End : TextAlign.Start)
                      .copyOption(CopyOptions.LocalDevice)
                  } else {
                    Column({ space: 8 }) {
                      LoadingProgress()
                        .width(22)
                        .height(22)
                        .color($r('app.color.accent'))
                      Text('正在连接，最长等待 45 秒')
                        .fontSize(11)
                        .fontColor($r('app.color.ink_muted'))
                    }
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .width(message.role === 'user' ? '76%' : '86%')
                .alignItems(message.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
                if (message.role !== 'user') {
                  Blank()
                }
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 24, bottom: 24 })
              .visualEffect(contentLightEffect())
            }
          }, (message: PracticeMessage) => `${message.id}-${message.revision}`)
          if (this.status.length > 0) {
            ListItem() {
              Row({ space: 12 }) {
                Text(this.status)
                  .layoutWeight(1)
                  .fontSize(13)
                  .lineHeight(21)
                  .fontColor($r('app.color.ink_muted'))
                if (this.status !== '已停止生成，可以继续输入。') {
                  ImmersiveAction({
                    label: '重试',
                    actionAccessibilityText: '重试 DeepSeek 场景请求',
                    icon: $r('sys.symbol.arrow_right'),
                    actionSize: 42,
                    onAction: () => this.retry()
                  })
                }
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 10, bottom: 18 })
            }
          }
          ListItem() {
            Column()
              .height(104)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')

      Row({ space: 10 }) {
        TextInput({ text: this.draft, placeholder: this.generating ? 'DeepSeek 正在回应' : '用日语回应' })
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontColor($r('app.color.ink'))
          .placeholderColor($r('app.color.ink_muted'))
          .backgroundColor(Color.Transparent)
          .padding({ left: 4, right: 8 })
          .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
          .enabled(!this.generating)
          .maxLength(500)
          .enterKeyType(EnterKeyType.Send)
          .onChange((value: string) => this.draft = value)
          .onSubmit(() => this.send())
        if (this.generating) {
          ImmersiveAction({
            actionAccessibilityText: '停止生成',
            icon: $r('sys.symbol.xmark'),
            actionSize: 48,
            emphasized: true,
            onAction: () => this.stop()
          })
        } else {
          ImmersiveAction({
            actionAccessibilityText: '发送日语回应',
            icon: $r('sys.symbol.paperplane_fill'),
            actionSize: 48,
            actionEnabled: this.draft.trim().length > 0,
            emphasized: true,
            onAction: () => this.send()
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 18, top: 6, bottom: 18 })
      .borderRadius(28)
      .backgroundEffect({ radius: 30, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
      .border({ width: 0.5, color: $r('app.color.immersive_edge') })
      .visualEffect(planeLightEffect())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
