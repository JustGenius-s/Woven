# 词库数据模型

词库以 JMdict 词条为骨架，用 Waller 的 JLPT 标签标级别，用开放音调数据标发音。这不是全量 JMdict。考试词和考试外常用词已经打进 `entry/src/main/resources/rawfile/vocabulary/`。

| 级别 | 文件 | 划分 |
| --- | --- | --- |
| N5–N1 | `vocabulary/n5.json` … `n1.json` | 有社区考试标签的学习子集 |
| 日常 | `vocabulary/extra-daily.json` | 报纸频段 `nf01–nf16` 或 `ichi1` |
| 一般 | `vocabulary/extra-general.json` | 其余报纸频段 `nf17–nf48` |
| 补遗 | `vocabulary/extra-supplement.json` | 编辑标常用，但没有报纸频段 |

N5–N1 是社区估计，不是 JLPT 官方词表。当前打包约 7,742 条考试词和 15,433 条常用词。

## 字段

```json
{
  "id": "jmdict-1198180",
  "level": "N5",
  "word": "会う",
  "reading": "あう",
  "meanings": ["相遇；碰面；见面"],
  "common": true,
  "pitches": [{ "accent": 1, "morae": ["あ", "う"], "source": "wadoku" }],
  "example": { "japanese": "よく彼に会う。", "english": "I often see him." }
}
```

| 字段 | 来源 | 说明 |
| --- | --- | --- |
| `id` | JMdict `ent_seq` | 稳定主键。旅程和已学记录都指向它 |
| `word` | JMdict 主词形 | 汉字或假名 |
| `reading` | JMdict 主读音 | 平假名 |
| `level` | Waller / yomitan-jlpt-vocab，或频段分级 | `N5`–`N1`、`日常`、`一般`、`补遗` |
| `common` | JMdict `(P)` | 是否常用 |
| `meanings` | 现有释义 | 考试词为中文；部分常用词仍是英语 |
| `example` | 现有英日例句 | 可缺省。尚未换成多例句、音频和整句假名 |
| `pitches` | Wadoku，缺条用 Kanjium | 可为空数组 |

## 音调

`accent` 是东京式下调核：

- `0`：平板。第一拍低，其后高，助词也高。
- `1`：头高。第一拍高，其后低。
- `2…n-1`：中高。在第 `accent` 拍之后下降。
- `n`（等于拍数）：尾高。词内最后一拍后下降，助词低。

`morae` 按拍拆分：拗音算一拍，促音、拨音、长音各算一拍。同一读音有多个核时全部保留，第一条是默认展示。

来源顺序：

1. [Wadoku](https://github.com/WaDoku/WaDokuJT-Data)（CC BY-SA 3.0）
2. [Kanjium `accents.txt`](https://github.com/mifunetoshiro/kanjium)（作者宣称 CC BY-SA 4.0，只作补缺）

NHK、新明解等原典不进入离线包。归属见 `entry/src/main/resources/rawfile/licenses/VOCABULARY-NOTICE.md`。
