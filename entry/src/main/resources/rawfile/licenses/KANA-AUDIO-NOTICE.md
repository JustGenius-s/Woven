# 假名读音音频

`entry/src/main/resources/rawfile/audio/kana/` 收录了五十音图中每个假名的读音（共 102 个 MP3，
按罗马字命名，如 `a.mp3`、`cha.mp3`）。「お」与「を」分别映射到 `o.mp3` 与 `wo.mp3`。

## 来源

音频取自 <https://github.com/Kuuuube/kana-quiz-sounds>（`audio/0`，女声一组）。

该仓库在 `audio/README.md` 中记录的上游来源为：

| 分组 | 来源 | 授权 |
|---|---|---|
| 0 | Unknown | 未标注 |
| 1 | Unknown | 未标注 |
| 2 | <https://lets-dango.com/hiragana-and-katakana-pronunciation-with-audio/> | 站点自有版权 |
| 3 | <https://www.tofugu.com/japanese/learn-hiragana/> | Tofugu 自有版权 |
| 4 | YouTube `Bsfi4XbPE8M` | 未标注 |

本应用使用的是分组 0，仓库未标注其具体来源与授权。仓库整体以 GPL-3.0 发布。

## 注意

**这批音频的上游授权尚未确认。** 在将应用对外发布之前，应替换为已取得授权的
录音（自行录制，或明确以 CC0 / CC BY / 公共领域发布的素材），并同步更新本文件。

替换时保持文件名与罗马字一致即可，无需改动代码。
