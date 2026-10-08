# 教材阅读

入口：基础 → 文法 → 入门书架第一张《やらまいか日本語》封面。教材复用其他教材的
CoverCard、封面尺寸、离线标记和阅读图标，点击封面直接阅读；探索页不再展示该教材入口。
应用使用 Reader Kit 重排阅读，入口不再向用户展示“重排版”或试验性质的名称。
用户提供的《やらまいか日本語 新装二版》源 PDF 共 72 页，SHA-256 为
b41ff392f7720ac135563b513849b1ba7accec94e367058b3a417db65cbf4958。

## 当前完整重排版

完整教材的 20 个章节、71 个非空白页面均已按用户确认的第 11、17 页方式生成，跳过空白第 2 页。
区域配置位于 content/reader-semantic-full/，文字、原字体、字色、描边、插图和边框取自源文件。
正文英文名称、尺码和出版信息保留，去除罗马字注音；日文读音与正文关联。原图中烘焙的文字仍属于图片。

点击教材封面进入 pages/NativeReaderPage，使用 Reader Kit 原生分页，
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

`yaramaika-fixed.epub` 保留在 `content/reader-source/`：它是 pdf2htmlEX 的 XHTML/CSS/WOFF 与无文字底图，
重排管线仍以它和源 PDF 为输入。它不再参与应用显示，也不再打入安装包。
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

## 2026-10-08 目录真机显示调整

按用户要求对照原 PDF 第 4 页并在连接的手机上检查。Reader Kit 真机未呈现目录文字的
CSS 描边，导致透明填色的“もくじ”不可见、浅黄色课名对比不足。目录主标题、课号、
课名和原书页码现由原字体及字形位置生成局部透明 PNG，带替代文本；标题使用实色灰。
这些装饰标签按 em 设置宽度并受所在列约束，例句仍为可换行文字，保留源色相并加深
到白底可读的颜色。未恢复此前按要求去除的罗马字注音。

目录每个源页使用一张固定列宽表格，课号、课名、原书页码分别占 12%、78%、10%，
同一课尽量不拆页，右侧边线在表格内连续；源 PDF 第 4、5 页的表格之间仍有间隔。
生成过程新增 40 张目录标签，更新书籍缓存哈希。目录文字及其余 19 章 XHTML 与修改前
一致，XML 和资源引用核对通过。调试签名构建、手机覆盖安装通过；18 号字真机已确认
目录标题恢复、课名描边可见、第一页显示 01–06，第 07 课在下一页完整接续。
目录 XHTML 保留章节链接，但本次点按被阅读器处理成翻页，未确认正文链接跳转；
可继续通过“阅读设置 → 章节”跳转。

## 2026-10-08 接入文法

《やらまいか日本語》置于 BasicsPage 的文法“入门”书架第一张封面，在在线课表的加载、失败和空列表状态下
仍可打开。探索页旧入口已移除。TextbookReaderService 接替 NativeReaderTrial，继续使用原有
缓存路径及阅读进度键；阅读页显示“新装二版”，失败时可“返回文法”。封面来自原 PDF 第 1 页。
按用户要求使用与其余教材相同的书封展示，移除单独的大介绍卡和阅读按钮。
教材沿用既有阅读位置和字号。
真机确认首张书封可以打开教材，其余级别书架正常显示。
