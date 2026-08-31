# Woven · HarmonyOS 日语学习 App

一款使用 ArkTS 与 ArkUI 构建的 HarmonyOS 原生日语学习应用。课程内容离线运行；AI 对练与内容问答可由用户在设备本地配置 DeepSeek API Key 后直连官方 API，不依赖自建网关。

## 主要功能

- 场景旅程：以“入景 → 识音 → 记词 → 懂句 → 会话 → 开口”贯通五十音、词汇、语法、日常对话和开口练习；当前旅程及完成阶段会保存在本地。
- 五十音：清音、浊音/半浊音、拗音在同一纵向页面完整展示，并与当前旅程的关键声音关联。
- 语法：75 课 N5–N2 离线课程，横向滑动切课；课内纵向阅读，文中词汇点按后原位显示释义。
- 词汇：7,742 条 N5–N1 离线词汇，支持按级别和关键词检索；选中词集中显示读音、释义和例句。
- 探索：音乐、阅读、场景三个原生子页签；音乐与场景使用原创沉浸主视觉，阅读收录 5 篇青空文库开放文学节选并展示来源与权利信息。
- 日常对话：5 组内置旅程对话，按人物呈现台词、读音和释义。
- AI 对练：5 个角色任务；支持离线开场提示，也可使用 `deepseek-v4-flash` 进行多轮对话。
- 内容问答：从假名、单词、例句、语法段落或对话行直接打开上下文 AI Sheet，并围绕所选内容连续追问。
- 沉浸光感：API 23 上由页面级动态光源统一驱动正文和内容平面，使用 HDS `pointLight`、`pressShadow` 与官方 `systemMaterialEffect`；系统不支持时由框架降级。
- HDS 组件：导航、悬浮导航栏、核心动作和选择行使用官方 HDS 组件，并跟随系统深浅色。

## 目录

```text
entry/                         HarmonyOS 应用模块
  src/main/ets/                ArkTS 模型、服务和 ArkUI 页面
  src/main/resources/rawfile/  打包在应用内的离线学习内容
scripts/                       内容校验与 HAP 构建脚本
```

## DeepSeek 对练

在 App 的「我的 → 设置」中填写 DeepSeek API Key。Key 只写入应用私有的本地偏好数据，不进入源码或 Git；AI 对练和内容问答请求由 App 直接发送到 `https://api.deepseek.com/chat/completions`，离线课程浏览本身不会调用 AI。

## 校验与构建

内容完整性：

```bash
npm run check:content
```

macOS + DevEco Studio 默认安装路径下构建 HAP：

```bash
npm run build:hap
```

输出位于 `entry/build/default/outputs/default/`。仓库不包含签名凭据；真机安装前，需在 DevEco Studio 为 `default` product 配置调试或发布签名，然后重新构建。

## 内容来源

词汇与语法内容的许可和归属文件已一起打包在 `entry/src/main/resources/rawfile/content/licenses/`。开放阅读、音乐元数据和音频候选源的接入边界见 [`docs/OPEN_CONTENT.md`](docs/OPEN_CONTENT.md)；机器可读清单位于 `entry/src/main/resources/rawfile/content/open-sources.json`。N1–N5 词汇级别是社区估计，不是 JLPT 官方词表。
