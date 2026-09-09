# 已确认的第 11、17 页语义基准

独立预览为 docs/previews/reader-semantic-trial.html。全书配置仍引用本目录的 book.json，
其中的源文件哈希、字体过滤规则和两页区域定义是当前完整版本的输入，不能作为过期试验删除。

文字、字体、字色、描边取自原版 pdf2htmlEX XHTML/CSS/WOFF，底色和边框取自源 PDF 的绘图操作。
semantic-layout.cjs 恢复相连的句型单元格和局部图示锚点，渲染与全书共用 semantic-preview.cjs/css 和 semantic-diagram.js。

## 保留的效果与边界

- 正文、对话、句型框按可用宽度重排，背景和边框随文字撑高。
- 原字体的字宽、颜色、描边和下划线保留；横向压缩/拉伸字体生成对应 WOFF 变体。
- 地图使用原底图和局部坐标。标注随字号调整，空间不足时移入图外并连接原图内锚点。
- 标注避让依赖浏览器脚本，不意味着已完成 Reader Kit 适配。
- 区域与阅读关系由本书配置明确提供，不是任意 PDF 的自动分类器。旋转、嵌套裁切等未支持输入仍需另外适配；扫描件需要 OCR 输入流程。

## 重建独立预览

依赖 Node.js 的 pdfjs-dist、pngjs，Python 的 fontTools、lxml。

    node scripts/rebuild-reader-semantic-trial.cjs --pdf 'C:/path/to/original.pdf' --python 'C:/path/to/python.exe'

源 PDF 按 SHA-256 校验，缓存位于 .cache/reader-semantic-source/。
该命令只生成两页 HTML 和模型，不替换应用全书。预览与模型留在本地，通过 .gitignore 排除。
当前应用全书由 scripts/build-readerkit-full.cjs 生成，详见 [全书配置](../reader-semantic-full/README.md)。
本目录的两页区域定义仍是全书的输入；除此之外它只用于独立重建预览，不再生成应用内的试版 EPUB。

早期“仅替换两页、叠加旧 EPUB”的应用生成流程已归档；配置中的历史替换位置保留作为记录，
当前全书不使用这部分字段。恢复说明见 [整理记录](../../docs/READER_CLEANUP.md)。
按照用户要求，不自行运行测试、不查看生成页面效果、不安装设备。
