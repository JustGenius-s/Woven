# 日语本地朗读

单词、例句和对话行的合成语音使用：

- 运行时：[sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)（Apache-2.0），HarmonyOS HAR 包名为 `sherpa_onnx`
- 声线：Piper `ja_JA-hi_fi_captain-medium`（MIT），来自 [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices)
- 音素前端：espeak-ng 数据，随 sherpa-onnx TTS 模型包分发

训练语料是 HI-FI-CAPTAIN。对外发布前应再核对该语料的使用范围。

五十音仍使用打包录音，不走 TTS。最新 piper-plus（MB-iSTFT-VITS2）与当前 sherpa-onnx 不兼容，因此没有采用。
