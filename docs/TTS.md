# 日语本地 TTS

系统 `@kit.CoreSpeechKit` 没有 `ja-JP`。朗读走 **sherpa-onnx + 标准 Piper 日语模型**，在设备上合成，不经过系统 TTS，也不经过云端。

## 为什么不是 piper-plus

先前选定的接入路径是 sherpa-onnx。最新 [piper-plus](https://github.com/ayutaz/piper-plus) 日语模型是 MB-iSTFT-VITS2，而且部分声线（如つくよみちゃん）授权更紧。sherpa-onnx 目前按经典 VITS/Piper 推理，接不上这条模型。

因此默认声线换成官方 Piper `ja_JA-hi_fi_captain-medium`（MIT）。Worker 只认 `rawfile/tts/vits-piper-ja/` 这一套文件名，以后要换兼容的 VITS/Piper 模型，覆盖目录即可。

## 接入一次

1. 在 `entry` 模块安装运行时：

   ```bash
   cd entry
   ohpm install
   ```

2. 拉取并转换模型（约 80 MB，不进 Git）：

   ```bash
   npm run fetch:tts
   ```

3. 用 DevEco 编 HAP。第一次点朗读会把 `espeak-ng-data` 拷到应用沙箱，之后同一句话走本地 WAV 缓存。

没有模型时点击朗读是静音，课程浏览不受影响。

## 应用里怎么用

| 位置 | 行为 |
|---|---|
| 词汇列表喇叭 | 读 `reading` 假名 |
| 单词学习卡 | 点按大字朗读单词；例句旁喇叭读整句 |
| 旅程对话行 | 点按读 `reading`，没有读音时退回原句 |
| 五十音 | 仍播 `audio/kana/*.mp3` |

输入优先喂假名，避免汉字多音字被读错。
