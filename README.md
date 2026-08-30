# 言葉（Kotoba）HarmonyOS App

一款使用 ArkTS 与 ArkUI 构建的 HarmonyOS 原生日语学习应用。AI 通过独立 Node.js 网关访问；OpenAI API Key 不会进入 HAP。

```text
HarmonyOS App  ── OpenAI Responses JSON / SSE ──▶  AI 网关
                                                        │
                                                        ├─ AI SDK `openai.responses()` ─▶ OpenAI
                                                        └─ NHK RSS / 文章正文
```

## 主要功能

- 五十音：清音、浊音/半浊音、拗音在同一纵向页面完整展示。
- 语法：75 课（N5–N2），横向滑动切课；课内纵向阅读，文中词汇点按后原位显示释义，没有分页按钮和页码。
- 词汇：7,742 条 N5–N1 离线词汇，按级别和关键词检索；选中的词在词典舞台集中显示读音、释义和已有例句，结果区使用 HDS 懒加载列表。
- 日常对话：5 组内置场景，按人物左右错位呈现，读音和释义直接跟随台词。
- AI 对练：5 个场景；开始后隐藏主导航和设置，场景置顶，对话居中，支持 Responses 流式输出和 `previous_response_id` 多轮延续。
- 新闻：横向切换文章，单篇正文纵向完整阅读；正文使用杂志式段落层次，AI 精读结果直接融合在内容流中。
- 视频学习：保存视频链接和用户提供的字幕/文稿，AI 只分析真实提供的文本，不伪造自动转录。
- 内容舞台：学习首页、词典、课文、新闻、视频和对练不共用列表模板；分别采用学习入口、词典焦点、长文编排、横向文章、字幕时间线和单场景舞台。
- 沉浸光感：API 23 上由页面级动态光源统一驱动正文和内容平面，使用 HDS `pointLight`、`pressShadow` 与 AI 生成时的 `DUAL_EDGE_FLOW_LIGHT`；导航和悬浮导航栏继续使用官方 `systemMaterialEffect`。系统不支持时由框架降级，不用 `backdropBlur` 仿造材质。
- HDS 组件：导航、悬浮导航栏、核心动作、选择行和即时反馈分别使用官方 `HdsNavigation`、`HdsTabs`、`HdsActionBar`、`HdsListItem` 与 `HdsSnackBar`。输入框嵌入统一受光内容平面，不再作为孤立表单卡片出现。
- 主题：跟随系统深浅色；环境光、内容平面和系统材质共用暖灰底色与珊瑚强调色。

## 目录

```text
entry/                         HarmonyOS 应用模块
  src/main/ets/                ArkTS 模型、服务和 ArkUI 页面
  src/main/resources/rawfile/  已打包的离线学习内容
gateway/                       AI SDK + OpenAI Responses 兼容网关
scripts/                       内容校验与 HAP 构建脚本
```

## 运行 AI 网关

需要 Node.js 22+ 和 pnpm。

```bash
pnpm install --registry=https://registry.npmjs.org/
cd gateway
cp .env.example .env
# 在 .env 填写 OPENAI_API_KEY
pnpm build
pnpm start
```

默认模型为 `gpt-5.6-luna`。网关使用 AI SDK 的 `openai.responses(model)`，而不是 Chat Completions。当真机或模拟器联调时，将 `.env` 中的 `HOST` 改为 `0.0.0.0`，再在 App 的「连接设置」中填写电脑局域网地址，例如 `http://192.168.1.20:8787`。正式环境应使用 HTTPS。

App 中的「应用访问令牌」对应网关的 `KOTOBA_APP_TOKEN`，它不是 OpenAI API Key。移动客户端无法保密固定令牌；公网部署时还应在反向代理层加入用户身份、限额和设备风控。

### Responses 协议范围

`POST /v1/responses` 实现了当前 App 使用的文本子集：

- 请求：`model`、`instructions`、`input`、`stream`、`store`、`previous_response_id`、`max_output_tokens`。
- 流事件：`response.created`、`response.output_item.added`、`response.content_part.added`、`response.output_text.delta`、`response.output_text.done`、`response.content_part.done`、`response.output_item.done`、`response.completed`、`response.failed`。
- 非流请求返回 `object: "response"` 和 `output_text` 内容。

这不是 OpenAI Responses API 所有多模态、工具调用与文件能力的通用代理；未实现的字段不会被假装支持。

## 校验与构建

内容完整性：

```bash
node scripts/check-content.mjs
```

AI 网关：

```bash
pnpm --filter @kotoba/ai-gateway typecheck
pnpm --filter @kotoba/ai-gateway test
```

macOS + DevEco Studio 默认安装路径下构建 HAP：

```bash
scripts/build-hap.sh
```

输出位于 `entry/build/default/outputs/default/`。仓库不包含签名凭据；真机安装前，需在 DevEco Studio 为 `default` product 配置你自己的调试或发布签名，然后重新构建。

## 内容来源

词汇与语法内容的许可和归属文件已一起打包在 `entry/src/main/resources/rawfile/content/licenses/`。N1–N5 词汇级别是社区估计，不是 JLPT 官方词表。新闻是运行时读取的外部内容，发布商业版前应单独确认新闻源的使用条款与展示权限。
