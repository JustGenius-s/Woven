# 原创视觉素材记录

生成方式：OpenAI 内置图像生成。所有项目内图片均保留对应的高分辨率原图于 Codex `generated_images` 目录；应用资源为缩放后的交付副本。

## 共用视觉约束

- HarmonyOS 原生内容应用取向，成熟、克制、非模板化。
- 半扁平矢量与轻绘画质感结合，柔和空间层次与细微纸张颗粒。
- 不在图片中烘焙标题、按钮、Logo、水印、字母或数字。
- 音乐和阅读卡为全出血画面；场景卡在下方预留较暗的 UI 文本区；旅程插画使用透明背景。
- 词库封面为 3:2 全出血横图，主体集中在右上区域，左侧与下方保留浅色低细节空间供原生 UI 叠字。

## Prompt set

| 资源组 | 基础 prompt | 各资源主题 |
| --- | --- | --- |
| 旅程 | “Create an original transparent-background editorial spot illustration for a polished HarmonyOS Japanese-learning journey card; refined semi-flat vector-meets-painted style, restrained Japanese palette, no text/logos/UI/watermark.” | 五十音图：假名纸片与笔；单词：词卡与生活物件；语法：句子结构与连接；音乐：耳机与声波；阅读：打开的书与光；场景：对话气泡与城市空间。 |
| 词库 | “Create one original 3:2 landscape full-bleed category cover for a polished HarmonyOS Japanese-learning vocabulary card; refined semi-flat vector-meets-painted editorial style, airy layered-paper landscape, matte texture and subtle fine grain; keep the left side and lower third quiet and pale for native dark UI text; no readable writing, text, letters, numbers, logos, UI, borders, or watermark.” | N5：空白笔记本、词卡、嫩芽与朝阳；N4：自行车、街区小径与踏石；N3：小桥、汇流路径、空白词卡与树；N2：书、耳机、报纸与台灯；N1：空白书、砚台、笔、山茶与月；日常：早餐、伞、钥匙与交通卡；一般：地图、地球、城市与票券；补遗：档案盒、索引卡、放大镜、编辑铅笔与回形针。 |
| 音乐 | “Create one original square full-bleed album artwork for a premium Japanese-learning music card; cinematic editorial illustration, subtle grain, no text/logos/UI/watermark.” | 清晨电车、雨天咖啡店、小小旅行、海边的信、仰望星空。 |
| 阅读 | “Create one original 3:4 full-bleed default cover for a HarmonyOS Japanese picture-book card; quiet paper-craft still life, no title/text/logos/UI/watermark.” | 打开的绘本、和纸、山茶与晨光（默认封面 `reading_default`）。 |
| 场景 | “Create one original landscape 3:2 editorial illustration for a polished HarmonyOS Japanese-learning scenario card; show a concrete human interaction, reserve quieter darker lower-third space for UI, no readable text/logos/UI/watermark.” | 咖啡店点单、街头问路、餐厅说明忌口、办公室周末寒暄、语言交换表达观点。 |

生成后的素材只承担氛围与内容识别；所有可访问文本、状态、进度和操作仍由 ArkUI 原生组件绘制。
