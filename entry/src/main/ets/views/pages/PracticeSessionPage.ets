import { PracticeScenario } from '../../model/ContentModels';
import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import {
  PracticeMessage,
  ResponseInputMessage,
  ResponsesCreateRequest
} from '../../model/AiModels';
import { ResponsesClient } from '../../services/ResponsesClient';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { aiFlowEffect, contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';

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
  gatewayUrl: string = '';
  appToken: string = '';
  model: string = '';
  onExit: () => void = () => {};

  @State private messages: PracticeMessage[] = [];
  @State private draft: string = '';
  @State private generating: boolean = false;
  @State private previousResponseId: string = '';
  @State private status: string = '';
  private client?: ResponsesClient;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    setTimeout(() => this.begin(), 180);
  }

  aboutToDisappear(): void {
    this.client?.cancel();
  }

  private begin(): void {
    if (this.messages.length > 0 || this.generating) {
      return;
    }
    this.request('场景已经开始。请以你的角色先自然开口，不要解释规则。');
  }

  private send(): void {
    const value: string = this.draft.trim();
    if (value.length === 0 || this.generating) {
      return;
    }
    this.draft = '';
    this.appendMessage('user', value);
    this.request(value);
  }

  private request(userText: string): void {
    this.client = new ResponsesClient(this.gatewayUrl, this.appToken);
    this.generating = true;
    this.status = '';
    const assistantId: string = this.appendMessage('assistant', '');
    const input: ResponseInputMessage[] = [{
      role: 'user',
      content: [{ type: 'input_text', text: userText }]
    }];
    const request: ResponsesCreateRequest = {
      model: this.model,
      instructions: this.instructions(),
      input: input,
      stream: true,
      store: true
    };
    if (this.previousResponseId.length > 0) {
      request.previous_response_id = this.previousResponseId;
    }
    this.client.stream(request, {
      onDelta: (delta: string) => this.appendDelta(assistantId, delta),
      onCompleted: (responseId: string) => {
        this.previousResponseId = responseId;
        this.generating = false;
        this.scrollToLatest();
      },
      onError: (message: string) => {
        this.generating = false;
        this.status = message;
        showImmersiveNotice(this.getUIContext(), '对练暂时中断', message);
        this.removeIfEmpty(assistantId);
      }
    }).catch(() => {
      this.generating = false;
      this.removeIfEmpty(assistantId);
    });
  }

  private instructions(): string {
    return `你正在进行日语角色扮演。场景：${this.scenario.setting}。你扮演：${this.scenario.aiRole}。学习者扮演：${this.scenario.learnerRole}。难度：${this.scenario.level}。目标：${this.scenario.goal}。主要使用自然日语，每次一到两句，保持角色，不要输出标题、列表、Markdown 或教学说明。如果学习者表达影响理解，只在日语回应后追加一行简短中文纠正，格式为“自然表达：...”。`;
  }

  private appendMessage(role: string, text: string): string {
    const id: string = `${role}-${Date.now()}-${this.messages.length}`;
    this.messages = this.messages.concat([{ id: id, role: role, text: text }]);
    this.scrollToLatest();
    return id;
  }

  private appendDelta(id: string, delta: string): void {
    const next: PracticeMessage[] = this.messages.slice();
    for (let index: number = 0; index < next.length; index++) {
      if (next[index].id === id) {
        next[index] = { id: next[index].id, role: next[index].role, text: next[index].text + delta };
        break;
      }
    }
    this.messages = next;
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

        Row() {
          Column({ space: 5 }) {
            Text(this.scenario.learnerRole)
              .fontSize(11)
              .fontColor($r('app.color.accent'))
            Text('あなた')
              .fontSize(9)
              .fontColor($r('app.color.ink_muted'))
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('×')
            .fontSize(18)
            .fontColor($r('app.color.ink_muted'))
          Blank()
          Column({ space: 5 }) {
            Text(this.scenario.aiRole)
              .fontSize(11)
              .fontColor($r('app.color.ink'))
            Text('AI')
              .fontSize(9)
              .fontColor($r('app.color.ink_muted'))
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 13, bottom: 13 })
        .margin({ left: 20, right: 20, bottom: 4 })
        .borderRadius(22)
        .backgroundEffect({ radius: 24, color: $r('app.color.immersive_plane'), saturation: 1.06 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())

        List({ space: 0, scroller: this.scroller }) {
          ForEach(this.messages, (message: PracticeMessage, index: number) => {
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
                      .fontSize(message.role === 'user' ? 22 : 28)
                      .fontWeight(message.role === 'user' ? FontWeight.Medium : FontWeight.Bold)
                      .fontColor($r('app.color.ink'))
                      .lineHeight(message.role === 'user' ? 33 : 40)
                      .textAlign(message.role === 'user' ? TextAlign.End : TextAlign.Start)
                  } else {
                    LoadingProgress()
                      .width(22)
                      .height(22)
                      .color($r('app.color.accent'))
                  }
                }
                .width(message.role === 'user' ? '76%' : '86%')
                .alignItems(message.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
                if (message.role !== 'user') {
                  Blank()
                }
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 25, bottom: 25 })
              .visualEffect(message.text.length === 0 ? aiFlowEffect(true) : contentLightEffect())
            }
          }, (message: PracticeMessage) => message.id)
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

      Column({ space: 7 }) {
        Row({ space: 10 }) {
          TextInput({ text: this.draft, placeholder: this.generating ? 'AI 正在回应' : '用日语回应' })
            .layoutWeight(1)
            .height(48)
            .fontSize(16)
            .fontColor($r('app.color.ink'))
            .placeholderColor($r('app.color.ink_muted'))
            .backgroundColor(Color.Transparent)
            .padding({ left: 4, right: 8 })
            .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
            .enabled(!this.generating)
            .enterKeyType(EnterKeyType.Send)
            .onChange((value: string) => this.draft = value)
            .onSubmit(() => this.send())
          ImmersiveAction({
            actionAccessibilityText: '发送日语回应',
            icon: $r('sys.symbol.paperplane_fill'),
            actionSize: 48,
            actionEnabled: !this.generating && this.draft.trim().length > 0,
            emphasized: true,
            onAction: () => this.send()
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 8, top: 6, bottom: 6 })
        .borderRadius(28)
        .backgroundEffect({ radius: 30, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())
      }
      .width('100%')
      .padding({ left: 20, right: 18, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
