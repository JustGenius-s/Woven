# Woven

HarmonyOS 原生日语学习应用，用 ArkTS / ArkUI 编写。课程内容离线可用。AI 对练、日语朗读和文法实时语音由用户在本机填写密钥后直连对应服务，不经过自建网关。

## 功能

- **旅程**：入景、识音、记词、懂句、会话、开口。进度保存在本机。
- **基础**：五十音图，以及 Irodori《生活の日本語》文法课。课文和分课音频按需下载。
- **词汇**：7,742 条 N5–N1 考试词，15,433 条考试外常用词（日常 / 一般 / 补遗）。级别是社区估计，不是 JLPT 官方词表。
- **探索**：音乐、阅读、场景。阅读含青空文库节选和 Tadoku 绘本。
- **对话与 AI**：内置旅程对话；5 个角色对练；可从假名、单词、例句、语法或对话行追问。
- **账号**：华为账号登录后，可同步学习进度、已学单词和对话。未配置 AppGallery Connect 时只用本地数据。

## 开始使用

需要 macOS 上的 DevEco Studio，以及 HarmonyOS SDK `26.0.0`。

```bash
npm run build:hap
```

| 产品 | 输出 |
| --- | --- |
| 默认发布包 | `entry/build/default/outputs/default/` |
| 模拟器调试包 | `entry/build/emulator/outputs/default/` |

`build-profile.json5` 里的证书路径和加密口令属于本机签名配置。证书、Profile 和密钥库不在仓库中，换机器后需要重新配置签名。

密钥都在「我的 → 设置」填写，只写入应用私有存储，不进 Git，也不参与云同步。

| 用途 | 服务 | 未配置时 |
| --- | --- | --- |
| AI 对练、内容问答 | [DeepSeek](https://api.deepseek.com) | 离线浏览不受影响 |
| 词汇、例句、对话朗读 | [MiniMax](https://platform.minimaxi.com) | 点朗读没有声音。五十音仍用打包录音 |
| 文法页实时语音 | [火山引擎语音](https://console.volcengine.com/speech/new/setting/apikeys?projectName=default) | 入口转到设置页 |

## 文档

| 主题 | 说明 |
| --- | --- |
| [词库字段](docs/VOCABULARY_SCHEMA.md) | JSON 结构、音调规则、文件划分 |
| [开放内容](docs/OPEN_CONTENT.md) | 已打包来源和接入边界 |
| [日语朗读](docs/TTS.md) | MiniMax 语音合成 |
| [文法实时语音](docs/GRAMMAR_REALTIME_VOICE.md) | 火山引擎全双工伴读 |
| [华为账号与云同步](docs/HUAWEI_ACCOUNT_CLOUD_SYNC.md) | AGC 配置和云表 |
| [视觉素材](docs/GENERATED_ASSETS.md) | 原创封面的生成约束 |

许可与归属随应用打包在 `entry/src/main/resources/rawfile/licenses/`。机器可读来源清单是 `entry/src/main/resources/rawfile/open-sources.json`。

## 目录

```text
entry/src/main/ets/                 ArkTS 模型、服务和页面
entry/src/main/resources/rawfile/   离线学习内容
scripts/build-hap.sh                HAP 构建
```

## 许可

代码采用 [MIT License](LICENSE)。学习内容各自的许可见上方归属文件，不随 MIT 许可一并授予。
