# 日语 TTS 模型目录

运行时从这里读取 sherpa-onnx 的 Piper 日语模型。`vits-piper-ja/` 整目录都是本地产物，不进 Git。

预期布局：

```text
tts/vits-piper-ja/
  model.onnx
  tokens.txt
  espeak-ng-data/
```

在仓库根目录执行：

```bash
npm run fetch:tts
```

未放入模型时，朗读按钮保持静音，应用其余功能不受影响。
