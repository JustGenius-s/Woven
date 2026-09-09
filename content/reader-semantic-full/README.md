# 全书语义重排配置

当前应用采用本目录的完整版本。共 20 章，覆盖原 PDF 的 71 个非空白页面，仅跳过空白第 2 页。
第 11、17 页继续使用已确认试版的区域定义与排版，其余页面使用同一字体、图形和语义渲染流程。

## 数据与生成

- `book.cjs` 是可编辑的本书区域配置，只记录页面、区域、行列和图文归属，不重写教材句子。
- `docs/previews/reader-semantic-full-config.json` 是生成时导出的可读配置，不纳入源码管理。
- 原版 `yaramaika-fixed.epub` 提供 pdf2htmlEX 的 XHTML、CSS、内嵌 WOFF 与无文字底图。
- 原 PDF 提供背景色、边框、虚线、图片对象矩形等绘图信息。哈希不符会中止生成。
- `semantic-full-layout.cjs` 恢复内容关系；`semantic-geometry.cjs` 从共用边恢复多行单元格。
- `semantic-preview.cjs/css` 和 `semantic-diagram.js` 同时用于浏览器预览与应用。

```powershell
# 首次生成或修改字体提取规则后，重建源缓存：
node scripts/rebuild-reader-semantic-full.cjs --refresh-source --pdf 'C:/Users/justg/Downloads/PDF_yaramaikanihongo_print_ver.2.pdf' --python 'E:/Lib/Python/python.exe'

# 已有匹配缓存时，修改配置/渲染后直接生成：
node scripts/build-reader-web.cjs
```

Node 需要 `pdfjs-dist`、`jszip`、`pngjs`；源导入的 Python 需要 `lxml`、`fontTools`。
可通过 `NODE_PATH` 提供 Node 依赖。源缓存位于 `.cache/reader-semantic-full-source/`。

## 保留的关系

正文使用原字形、相对字号、字色、描边和下划线。源文件的横向压缩/拉伸字体生成相应的 WOFF 变体，
描边和填色的重复文字合并为一次显示。删除罗马字注音，正文英文名称、尺码及出版信息仍保留。
日文小字号读音转换为 ruby，与对应正文一同换行。

多行绿色句型框按实际边界恢复相连的单元格、纵向选项和点线空格。图卡的配图与说明在同一个单元内，
同组图片共享画框并等比缩放；原本位于图上、图下的说明分别保留在相应位置。
表格保留行列、合并单元格和底色；五十音表删除罗马字专用列，保留空单元格位置。
日历等行列必须共同阅读的表格，在大字号或窄窗口下可横向滚动。

图示标注使用局部原坐标，空间不足时移到图外并以引线连接原位置。
第 65 页的彩色文字框也作为标注的一部分一起伸缩、移动，旧固定框从底图中移除。
原文件已经烘焙进位图的文字（如第 71 页地图、部分证件）仍属于图片，不能作为独立文字调字号。

这是一套可复用的提取与渲染组件，加上本书明确的区域配置；其他 PDF 需要相应的区域和阅读关系配置。

## 输出与应用

- `docs/previews/reader-semantic-full.html`：自包含离线全书预览。
- `docs/previews/reader-semantic-full.json`：完整语义模型。
- `docs/previews/reader-semantic-full-audit.json`：转换记录，包含正文归属、剩余普通段落和图片对象归属。
- `entry/src/main/resources/rawfile/reader/yaramaika-semantic.zip`：应用完整书籍包，包含全部图片、字体、HTML、CSS 和脚本。
- `WebReflowContent.ets`：自动生成章节、缓存和进度版本信息。

生成器核对实际渲染字段中的源字符归属，遗漏或重复会中止生成。这是转换完整性约束，
不等于浏览器、真机或布局效果验收。按照用户要求不执行测试，不自行查看生成页面效果，不安装设备。

应用直接解包完整语义资源，不再拼接旧版章节，也不依赖旧 EPUB 的图片。
升级时保留之前的章节位置，重新建立本版本的位置锚点。阅读区域内连续排版，不按原 PDF 页强制分页。

旧版模板与教材 JSON 已归档，位置及恢复说明见 `docs/READER_CLEANUP.md`。
预览和转换记录留在原路径供查看，通过 `.gitignore` 排除；应用必需的书籍 ZIP 和 ArkTS 元数据继续保留。
