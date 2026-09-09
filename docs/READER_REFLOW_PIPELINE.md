# PDF 教材语义重排流程

当前完整教材使用 pdf2htmlEX 的原文字、字体和底图，加上源 PDF 的绘图信息，恢复可重排结构。
全书共 20 章、71 个非空白页面，跳过空白第 2 页。第 11、17 页继续复用用户已确认的区域定义。

## 配置与可复用组件

- content/reader-semantic-full/book.cjs：全书章节、区域、图卡行列、图文归属；不重写教材句子。
- content/reader-semantic-trial/book.json：第 11、17 页基准，以及源文件和字体过滤配置。全书仍引用它，必须保留。
- scripts/lib/reader-book/import-pdf2htmlex.py：读取 XHTML/CSS/WOFF，恢复字形、字宽、描边、颜色，合并重复绘制的文字，并处理横向压缩或拉伸字体。
- pdf-graphics.cjs：读取源 PDF 的底色、边框、虚线及图片对象矩形。
- semantic-layout.cjs：两页基准的结构恢复与全书共用的文字、图片、坐标处理函数。
- semantic-geometry.cjs、semantic-full-layout.cjs：恢复多行句型框、表格、图卡、目录、书写练习及图示的内容关系。
- semantic-text-inventory.cjs：核对实际渲染字段中的源字符归属，遇到遗漏或重复则中止转换。
- readerkit-epub.cjs、prepare-readerkit-assets.py：原生 EPUB 的 XHTML/CSS、源 TTF、局部标注合成与图卡画框。
- build-readerkit-book.cjs：两页试版与全书共用的 EPUB 打包和应用元数据生成。
- semantic-preview.cjs/css、semantic-diagram.js：预览与网页版共用的排版、原字体渲染和标注避让。
- reader-web.js/css：网页版阅读设置、章节切换、翻页与进度恢复。

正文自然换行，背景和边框随文字容器增长。图卡把插图、说明和价格绑定在一个单元中，
同组图片共享画框、居中等比缩放。表格保留行列及合并关系；五十音表移除罗马字专用列。
Reader Kit 中由原生引擎分页，表格列适配内容宽度，单元格文字允许换行；
网页版中的宽表可横向滚动。

原生版将地图、人体等图示的文字与彩色框固化在局部图中，整体缩放；普通文字仍然重排。
网页版图示保持局部锚点，标注放大后空间不足时移入图外文字行，以引线连接原位置。
带颜色边框的标注随文字一起伸缩、移动。原图里已烘焙的文字仍属于图片，不能独立调字号。
这套组件需要每本书相应的区域配置，不承诺任意 PDF 自动恢复全部阅读关系。

## 生成

依赖：Node.js 的 pdfjs-dist、jszip、pngjs，Python 的 fontTools、lxml、Pillow。可通过 NODE_PATH 提供 Node 依赖。

首次生成或更新源提取规则后重建缓存：

    node scripts/rebuild-reader-semantic-full.cjs --refresh-source --pdf 'C:/Users/justg/Downloads/PDF_yaramaikanihongo_print_ver.2.pdf' --python 'E:/Lib/Python/python.exe'

已有匹配源文件哈希的缓存时：

    node scripts/build-readerkit-full.cjs --python 'E:/Lib/Python/python.exe'

需要更新网页版时：

    node scripts/build-reader-web.cjs

独立重建两页基准预览，不替换应用书籍：

    node scripts/rebuild-reader-semantic-trial.cjs --pdf 'C:/Users/justg/Downloads/PDF_yaramaikanihongo_print_ver.2.pdf' --python 'E:/Lib/Python/python.exe'

源缓存位于 .cache/reader-semantic-full-source/。详细配置与边界说明见
[全书配置](../content/reader-semantic-full/README.md)。

## 输出与应用

- entry/src/main/resources/rawfile/reader/yaramaika-readerkit.epub：当前主入口的完整原生教材。
- entry/src/main/ets/services/ReaderKitContent.ets：原生全书的资源字节数、缓存哈希、章节及原页映射。
- .cache/readerkit-full-package/：原生转换的模型、图片及 audit.json，不纳入源码管理。
- entry/src/main/resources/rawfile/reader/yaramaika-semantic.zip：应用内置的完整 HTML、字体、图片、样式和脚本书籍包。
- entry/src/main/ets/services/WebReflowContent.ets：应用必需的生成元数据；以上两项继续纳入项目。
- docs/previews/reader-semantic-full.html：自包含离线全书预览。
- 同目录的 reader-semantic-full.json、reader-semantic-full-config.json、reader-semantic-full-audit.json：模型、导出配置和转换记录。

预览与 JSON 生成物保留在本地，但由 .gitignore 排除，不与手工维护的源配置重复管理。
当前完整教材主入口由 Reader Kit 分页与渲染，网页版保留 ArkWeb 的滚动翻页及动态图示布局。
两者均按实际可用阅读区域排版，不按原 PDF 页强制分页。原版与两页试版保留，详见 [教材阅读](NATIVE_READER_TRIAL.md)。

旧版模板流程、旧教材配置及历史两页覆盖生成器已归档，不再是当前构建的依赖。
归档与恢复说明见 [整理记录](READER_CLEANUP.md)。用户要求不自行测试：只整理源内容、生成资源和按需编译签名，效果由用户验收。
