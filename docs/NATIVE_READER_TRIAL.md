# 教材阅读

入口：探索 → 阅读 → 教材阅读 → **打开重排版（Reader Kit）/ 打开原版布局 / 打开网页版 / Reader Kit 试版 · 11、17 页**。
用户提供的《やらまいか日本語 新装二版》源 PDF 共 72 页，SHA-256 为
b41ff392f7720ac135563b513849b1ba7accec94e367058b3a417db65cbf4958。

## 当前完整重排版

完整教材的 20 个章节、71 个非空白页面均已按用户确认的第 11、17 页方式生成，跳过空白第 2 页。
区域配置位于 content/reader-semantic-full/，文字、原字体、字色、描边、插图和边框取自源文件。
正文英文名称、尺码和出版信息保留，去除罗马字注音；日文读音与正文关联。原图中烘焙的文字仍属于图片。

“打开重排版”现在进入 pages/NativeReaderPage，使用 Reader Kit 原生分页，
加载独立的 yaramaika-readerkit.epub。20 个章节沿用相同语义模型，正文、句型框、表格、
日文读音及图卡说明是可重排 XHTML，15 份原字体以 TTF 内嵌；表格保留行列与合并关系。
193 个图卡的图片按源画框补齐并居中，普通插图保留源分辨率，避免无意义放大文件。
26 个图示的文字及彩色标注框合成到各自的局部图片中，与图一起缩放，不执行浏览器脚本。

原生设置提供 16–32 字号、行距、章节列表、横滑/仿真翻页与“本章原版”。
按实际阅读区域分页，不按源 PDF 页强制分页；字体、背景、边框随容器排版。
ReaderKitContent.ets 记录字节数、缓存哈希、章节与源页对应关系。原生版使用独立的缓存和进度；
首次从网页版迁入时恢复到上次阅读的章节开头，不把浏览器滚动偏移当作原生阅读位置。
字号和行距设置会保存。全部复杂页面的设备显示效果仍由用户验收。

## 保留的网页版

“打开网页版”进入 pages/ReflowReaderPage，使用 ArkWeb，复用预览的字体、排版和标注避让脚本。
原生界面提供 16–40 字号、行距、章节定位、翻页与“本章原版”入口。
章节内连续排版，按实际阅读区域换行，上下页按钮移动一屏并衔接前后章，不按原 PDF 页强制分页。
不加入“原书第 x 页”等说明，目录保留原书印刷页码。

ReflowWebBook 将自包含的 yaramaika-semantic.zip 解包到内容哈希对应的目录，避免复用旧布局缓存。
网页版不依赖旧 EPUB；WebReflowContent.ets 记录书籍字节数、缓存版本、章节和原页映射。
升级时迁移以前的章节位置，之后保存本版本 HTML 元素锚点及偏移。字体、图片和标注布局完成后再恢复进度。

## Reader Kit 两页试版

新增入口“Reader Kit 试版 · 11、17 页”，路由到 NativeReaderPage，使用系统 ReadPageComponent、
BookParser 和 ReaderComponentController。书籍为独立的 yaramaika-readerkit-trial.epub，
只有原 PDF 第 11、17 页两个正文资源；用户确认效果后，主入口已扩展为 Reader Kit 全书。
两页试版 EPUB 与原版、网页版内容均保留。

生成器复用 content/reader-semantic-trial/book.json 和 semantic-layout 的语义模型，
不使用旧版手工重排 EPUB。正文、标题、句型框和填空是 XHTML，按实际阅读区域分页、换行；
相对字号、原文字颜色、下划线和描边写入 CSS，实际用到的 6 份源字体转换为内嵌 TTF。
原字号、字色、描边和表格样式能否全部被 Reader Kit 保留，仍以用户真机表现为准。
句型框采用可折行的 inline-table 词组，共享单元格边线，填空仍在所在词组内。

地图的文字使用相同源字体、局部坐标和字色合成进单张局部 PNG，和地图整体缩放；
地图以外的文字仍可重排。这里没有搬入 semantic-diagram.js 的浏览器避让运行时，
因此地图标注不会随正文字号独立放大、移到图外并生成引线。这是本次原生试版的明确边界。
地图替代文本保留标注名称。该试版不把整页转成图片，也不在正文添加原书页码说明。

阅读设置提供字号、行距、原生横滑/仿真翻页、两页快捷跳转和对应原版入口。
章节到原 PDF 的索引为 [10,16]；EPUB 内容哈希隔离试版缓存和阅读位置。
ReaderKitTrialContent.ets 由生成器维护，旧版 Reader Kit 基线仍保留。

## 原版与旧 Reader Kit 基线

原版由 pages/FixedLayoutReaderPage 的 ArkWeb 展示 yaramaika-fixed.epub 解包后的固定布局 HTML。
FixedLayoutBook 保留字体、CSS 和图片相对路径；fixed-layout.js 按可用区域缩放原画布，支持缩放、翻页和页码定位。
原版在显示层隐藏罗马字注音，原 EPUB 不变，缓存使用 files/reader-trial/fixed-web-v2/。
原版与重排版分别保存阅读进度。

NativeReaderPage、NativeReaderTrial 和两份章节元数据继续保留，作为 Reader Kit 接入基线。
对应的 yaramaika-reflow.epub（旧版完整教材）与 yaramaika-reflow-sample.epub（旧样本）也保留，
避免未来适配时丢失已有的解析、原生分页和阅读设置接入。它们不是当前完整重排版的显示内容。
“打开重排版”进入 Reader Kit 全书，“打开原版布局”和“打开网页版”使用 ArkWeb。
旧 EPUB 的生成器与源配置已归档，位置见 [整理记录](READER_CLEANUP.md)。

## 生成和打包

当前流程依赖 Node.js 的 pdfjs-dist、jszip、pngjs，Python 的 lxml 和 fontTools。
可通过 NODE_PATH 提供 Node 依赖。首次生成需原 PDF，后续可复用匹配哈希的源缓存。

    node scripts/rebuild-reader-semantic-full.cjs --refresh-source --pdf 'C:/Users/justg/Downloads/PDF_yaramaikanihongo_print_ver.2.pdf' --python 'E:/Lib/Python/python.exe'
    node scripts/build-reader-web.cjs
    node scripts/build-readerkit-full.cjs --python 'E:/Lib/Python/python.exe'
    node scripts/build-readerkit-trial.cjs --python 'E:/Lib/Python/python.exe'
    ./scripts/build-hap.ps1 -DevEcoHome 'E:/App/DevEco Studio'

原生全书及两页小样共用 build-readerkit-book.cjs、readerkit-epub.cjs、prepare-readerkit-assets.py，
默认只读全书源缓存，不改写网页版包和预览。全书的模型及转换记录在 .cache/readerkit-full-package/。
若源缓存不存在，可直接生成原生全书，无须先生成网页版：

    node scripts/build-readerkit-full.cjs --refresh-source --pdf 'C:/Users/justg/Downloads/PDF_yaramaikanihongo_print_ver.2.pdf' --python 'E:/Lib/Python/python.exe'

也可以独立准备两页缓存：

    node scripts/build-readerkit-trial.cjs --refresh-source --source .cache/readerkit-trial-source --pdf 'C:/Users/justg/Downloads/PDF_yaramaikanihongo_print_ver.2.pdf' --python 'E:/Lib/Python/python.exe'

原生生成额外需要 Python 的 Pillow，用于固化局部标注及统一图卡画框。

打包沿用项目现有签名配置，产物为 entry/build/default/outputs/default/entry-default-signed.hap。
当前全书预览为 docs/previews/reader-semantic-full.html；两页基准及旧版预览仍保留在原路径供用户对照。
这些 HTML 和模型为本地生成物，不纳入源码管理。

2026-09-09：全书语义资源生成完成，HAP 编译与签名通过。之后的源码清理不改变教材显示和 Reader Kit 接入。
同日新增 Reader Kit 两页试版：EPUB 1,724,492 字节，2 个正文资源、6 份字体、2 张局部图片；
包内 XML、资源引用和源页映射静态核对通过，应用编译与签名通过。
同日迁入原生全书：EPUB 17,883,969 字节，20 个章节、71 个源页面、15 份字体、308 张图片。
目录和资源引用、普通文字清单核对通过；第 11、17 页的 XHTML 内容与地图图片和已确认小样一致。
原生全书 HAP 编译与签名通过，包内全书、两页试版、网页版和原版资源与工作区内容一致。
第一、二课缺图反馈后的调整：已确认 EPUB 内课堂用语 17 张、问候 33 张图片及引用完整。
针对嵌套自动宽度容器与百分比图片的原生排版风险，图文行改为真实 table/td；
图片直接写入 PNG 宽高属性及 em 显示宽度，不再依赖行内容器反推尺寸。
问候的头像与台词按行关联，场景图使用普通块布局；取消整组不可拆页约束，避免大字号时整组过高。
所有章节的文字和图片引用、308 张 PNG 的内容与修改前一致；新 EPUB 为 17,884,538 字节。
缓存哈希随包更新，设备缺图是否消除仍待用户真机确认，未将静态核对当作设备效果验证。
按照用户要求，不运行测试、不自行查看生成页面效果、不操作设备安装；实际效果由用户验收。
