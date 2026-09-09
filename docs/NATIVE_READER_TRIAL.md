# 教材阅读

入口：探索 → 阅读 → 教材阅读 → **打开重排版**。应用只保留 Reader Kit 重排版一种阅读方式。
用户提供的《やらまいか日本語 新装二版》源 PDF 共 72 页，SHA-256 为
b41ff392f7720ac135563b513849b1ba7accec94e367058b3a417db65cbf4958。

## 当前完整重排版

完整教材的 20 个章节、71 个非空白页面均已按用户确认的第 11、17 页方式生成，跳过空白第 2 页。
区域配置位于 content/reader-semantic-full/，文字、原字体、字色、描边、插图和边框取自源文件。
正文英文名称、尺码和出版信息保留，去除罗马字注音；日文读音与正文关联。原图中烘焙的文字仍属于图片。

“打开重排版”进入 pages/NativeReaderPage，使用 Reader Kit 原生分页，
加载独立的 yaramaika-readerkit.epub。20 个章节沿用相同语义模型，正文、句型框、表格、
日文读音及图卡说明是可重排 XHTML，15 份原字体以 TTF 内嵌；表格保留行列与合并关系。
193 个图卡的图片按源画框补齐并居中，普通插图保留源分辨率，避免无意义放大文件。
26 个图示的文字及彩色标注框合成到各自的局部图片中，与图一起缩放，不执行浏览器脚本。

原生设置提供 16–32 字号、行距、章节列表与横滑/仿真翻页。
按实际阅读区域分页，不按源 PDF 页强制分页；字体、背景、边框随容器排版。
ReaderKitContent.ets 记录字节数、缓存哈希、章节与源页对应关系。
字号和行距设置会保存。全部复杂页面的设备显示效果仍由用户验收。

## 仅保留重排版

原版布局、网页版与 Reader Kit 两页试版已从应用移除，入口只剩“打开重排版”。

删除的阅读页面为 pages/FixedLayoutReaderPage 与 pages/ReflowReaderPage，路由表只留 pages/NativeReaderPage。
随之删除 FixedLayoutBook、ReflowWebBook、WebReflowContent、ReaderKitTrialContent、
NativeReaderContent、NativeReaderSampleContent，以及 rawfile 里的 yaramaika-semantic.zip、
yaramaika-readerkit-trial.epub、yaramaika-reflow.epub、yaramaika-reflow-sample.epub 和 fixed-layout.js。
阅读设置里不再有“本章原版”入口，NativeReaderTrial 只描述重排版这一版。

`yaramaika-fixed.epub` 保留在 rawfile：它是 pdf2htmlEX 的 XHTML/CSS/WOFF 与无文字底图，
重排管线仍以它和源 PDF 为输入。它不再参与应用显示，只作为生成源留在包内。
生成脚本与 content/ 配置未改动，仍可生成两页基准预览；试版 EPUB 的构建入口不再被应用使用。

旧 EPUB 的生成器与源配置已归档，位置见 [整理记录](READER_CLEANUP.md)。

## 生成和打包

当前流程依赖 Node.js 的 pdfjs-dist、jszip、pngjs，Python 的 lxml 和 fontTools。
可通过 NODE_PATH 提供 Node 依赖。首次生成需原 PDF，后续可复用匹配哈希的源缓存。

    node scripts/rebuild-reader-semantic-full.cjs --refresh-source --pdf 'C:/Users/justg/Downloads/PDF_yaramaikanihongo_print_ver.2.pdf' --python 'E:/Lib/Python/python.exe'
    node scripts/build-readerkit-full.cjs --python 'E:/Lib/Python/python.exe'
    ./scripts/build-hap.ps1 -DevEcoHome 'E:/App/DevEco Studio'

原生全书使用 build-readerkit-book.cjs、readerkit-epub.cjs、prepare-readerkit-assets.py，
默认只读全书源缓存。全书的模型及转换记录在 .cache/readerkit-full-package/。
若源缓存不存在，可直接生成原生全书：

    node scripts/build-readerkit-full.cjs --refresh-source --pdf 'C:/Users/justg/Downloads/PDF_yaramaikanihongo_print_ver.2.pdf' --python 'E:/Lib/Python/python.exe'

网页版书籍包与两页试版 EPUB 已不再打包，rebuild-reader-semantic-full.cjs 仍会生成
yaramaika-semantic.zip 与 WebReflowContent.ets，应用不再包含它们，下次生成可忽略这两项输出。

原生生成额外需要 Python 的 Pillow，用于固化局部标注及统一图卡画框。

打包沿用项目现有签名配置，产物为 entry/build/default/outputs/default/entry-default-signed.hap。
当前全书预览为 docs/previews/reader-semantic-full.html；两页基准预览仍保留在原路径供用户对照。
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
移除原版布局、网页版与两页试版后，HAP 编译与签名通过。包内只剩 yaramaika-readerkit.epub
与作为生成源保留的 yaramaika-fixed.epub，路由表为 pages/Index 与 pages/NativeReaderPage。
入口卡片只剩“打开重排版”。重排版 EPUB 未被改动，阅读效果应与清理前一致，仍由用户真机验收。
