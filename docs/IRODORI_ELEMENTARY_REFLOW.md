# Irodori 初级课程重排

范围为初级 1、初级 2 的第 1–18 课，共 36 课。使用各课独立 PDF，合订本、封面、前言、目录和自评表不重复导入课程。

2026-10-08 转换完成：36 个 EPUB、814 个原 PDF 页面，合计 141,834,803 字节。课程注册表已接入文法阅读入口，随后按用户要求编译成功并覆盖安装到手机，保留应用数据。

这批内容按用户要求仅转换，排版与内容由用户手工验收。未运行字符审计、字体导出复核、EPUB 验证器、浏览器预览、测试或手机排版检查。转换完成不代表验证通过。

## 生成

```sh
python3 scripts/build-irodori-elementary.py /path/to/IRODORI --node /path/to/node --jobs 3
```

Python 依赖 PyMuPDF、Pillow、numpy、fontTools，Node.js 依赖 pdfjs-dist。脚本提取每课原字体，并复用入门的正文、注音、表格、词汇图卡和局部图像转换流程；不套用入门专用页码和人工裁图坐标。无法映射为文字的字形保留为局部图像。

每课按原 PDF 页序建立 EPUB 章节。原字体与图片打入 EPUB，页脚保留课号、原页码和版权署名。复杂图组使用自动推断边界，尚未逐页人工调整。

转换记录、字体缓存及过程日志在 `.cache/irodori-elementary/`，不纳入 Git。日志记录转换进度，`conversion.json` 明确标记 `verification: not_run`。中断后仅在输入文件及转换规则未变化时使用 `--resume` 复用已完成课程。

全部转换完成后，脚本直接写入 `entry/src/main/resources/rawfile/reader/irodori-a21-lNN-reflow.epub` 与 `irodori-a22-lNN-reflow.epub`，生成 `IrodoriElementaryContent.ets`。此发布步骤仅复制转换结果和生成元数据，不执行验证。

## 应用接入

沿用现有文法书架和课程 ID（`irodori-a21-lNN`、`irodori-a22-lNN`），点击原课程封面进入 Reader Kit 阅读器，音频沿用课程资源。原 PDF 保留，不支持 Reader Kit 的设备继续使用既有 PDF 入口。

手工反馈可直接注明“初级 1/2、第几课、原 PDF 第几页”；阅读设置中的章节标题与原页码对应。
