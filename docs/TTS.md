# 日语朗读

词汇、例句和对话行的朗读走 MiniMax 语音合成。系统语音合成没有日语。请求由应用直连 `https://api-bj.minimaxi.com/v1/t2a_v2`，音频在本机播放，不经过自建服务。

## 配置

在「我的 → 设置 → MiniMax 日语语音」填写 API Key。Key 从 [platform.minimaxi.com](https://platform.minimaxi.com) 获取，只保存在本机，不进 Git，也不参与学习数据同步。

未填写时，点朗读没有声音，课程浏览不受影响。五十音继续播放已打包的 `audio/kana/*.mp3`。

## 应用内行为

| 位置 | 朗读内容 |
| --- | --- |
| 词汇列表 | `reading` 假名 |
| 单词学习卡 | 点大字读单词；例句旁的按钮读整句 |
| 旅程对话 | 优先读 `reading`，没有读音时读原句 |

输入优先使用假名，减少汉字多音字读错。
