# 词库数据模型

最后核对：2026-09-02

词库按「JMdict 词条为骨架，Waller JLPT 级别为标签，开放音调为发音」组装。
打包分两层，考试外常用词再按 JMdict 报纸频段拆三级：

- **N5–N1**：有社区考试标签的学习子集
- **日常**：考试表没收、但报纸频段 `nf01–nf16` 或 `ichi1` 的常用词
- **一般**：其余报纸频段（`nf17–nf48`）
- **补遗**：编辑标常用，没有报纸频段

这不是 20 万条全量 JMdict。全量太大，不适合整包进安装包。词和例句的朗读走设备上的 Piper TTS，不预生成音频文件。整句假名仍留给后期批量补。

## 一条词

```json
{
  "id": "jmdict-1198180",
  "level": "N5",
  "word": "会う",
  "reading": "あう",
  "meanings": ["相遇；碰面；见面"],
  "common": true,
  "pitches": [
    {
      "accent": 1,
      "morae": ["あ", "う"],
      "source": "wadoku"
    }
  ],
  "example": {
    "japanese": "よく彼に会う。",
    "english": "I often see him."
  }
}
```

| 字段 | 现在 | 来源 | 说明 |
|---|---|---|---|
| `id` | 必填 | JMdict `ent_seq` | 稳定主键，旅程和已学记录都指向它 |
| `word` | 必填 | JMdict 主词形 | 汉字或假名书写 |
| `reading` | 必填 | JMdict 主读音 | 平假名 |
| `level` | 必填 | Waller / yomitan-jlpt-vocab，或 `日常` / `一般` / `补遗` | `N5`–`N1` 是社区估计，不是官方词表；考试外常用词按报纸频段分级 |
| `common` | 必填 | JMdict `(P)` | 是否常用 |
| `pitches` | 必填，可空 | Wadoku → Kanjium | 东京式下调核。没有可靠开放数据时为 `[]` |
| `meanings` | 暂留 | 现有中文释义 | 这一轮不重做 |
| `example` | 暂留 | 现有英日例句 | 后期替换为多例句 + 音频 + 假名 |

## 音调

`accent` 使用 NHK / Wadoku 下调核：

- `0`：平板。第一拍低，后面高；助词也高
- `1`：头高。第一拍高，后面低
- `2…n-1`：中高。在第 `accent` 拍后下降
- `n`（等于拍数）：尾高。词内最后一拍后下降，助词低

`morae` 按东京式拍拆分：拗音（きゃ）一拍，促音・拨音・长音各一拍。
同一读音有多个核时按来源顺序全部保留，第一条是默认展示。

来源优先级：

1. [Wadoku](https://github.com/WaDoku/WaDokuJT-Data)（CC BY-SA 3.0）
2. [Kanjium `accents.txt`](https://github.com/mifunetoshiro/kanjium)（作者宣称 CC BY-SA 4.0，仅作补缺）

## 预留，这一轮不写进 JSON

后续生成时再加，避免现在把 7,742 条都撑上空字段。

```json
{
  "audio": {
    "word": { "id": "…", "license": "CC BY 4.0", "path": "audio/words/…" }
  },
  "examples": [
    {
      "id": "tatoeba-…",
      "japanese": "…",
      "chinese": "…",
      "audio": null,
      "furigana": [{ "ruby": "会", "rt": "あ" }]
    }
  ],
  "furigana": [{ "ruby": "会", "rt": "あ" }, { "ruby": "う" }]
}
```

考试外常用词走同一条结构，按频段拆成三个文件：

| 级别 | 文件 | 划分 |
|---|---|---|
| 日常 | `vocabulary/extra-daily.json` | `nf01–nf16` 或 `ichi1` |
| 一般 | `vocabulary/extra-general.json` | 其余 `nf17–nf48` |
| 补遗 | `vocabulary/extra-supplement.json` | 无报纸频段的编辑常用词 |

学习页进度按考试词 + 三级常用词合计。全量 JMdict 仍不打包。

## 重建

```bash
python3 scripts/build-vocabulary.py
```

脚本会刷新 N5–N1 的 `pitches`，并按报纸频段重建三级常用词。考试词的词头、级别、释义和例句不改。
原始 dump 缓存在 `.cache/vocab/`，不进 Git。

2026-09-02 重建结果：考试词 7,698 / 7,742 条有音调；常用词 日常 6,367、一般 4,253、补遗 4,813（合计 15,433，其中 14,244 有音调）。释义暂用 JMdict 英语，中文和例句后期补。
