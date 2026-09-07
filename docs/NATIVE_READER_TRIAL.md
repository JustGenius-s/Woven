# Reader Kit 原生阅读试用

入口：**探索 → 阅读 → 原生阅读试用 → 打开可重排版 / 打开原版布局**。

将用户提供的《やらまいか日本語 新装二版》完整 72 页 PDF 的两份转换产物，接入华为 Reader Kit 的 `BookParser` 和 `ReadPageComponent`。这一入口用于比较原生分页、翻页交互和教材排版适配，现有书架的 PDF 阅读入口保持原有行为。

## 教材与转换

原文件：`/Users/morisi/hamamatsu-nihongo/03_やさしい日本語/PDF_yaramaikanihongo_print_ver.2.pdf`。

原 PDF SHA-256：`b41ff392f7720ac135563b513849b1ba7accec94e367058b3a417db65cbf4958`。

| 内置资源（`entry/src/main/resources/rawfile/reader/`） | 转换方式 | 内容 |
| --- | --- | --- |
| `yaramaika-fixed.epub` | pdf2epubEX / pdf2htmlEX 0.18.8.rc2，150 dpi PNG | EPUB 3 固定布局，72 个页面资源 |
| `yaramaika-reflow.epub` | pdf2epubEX 的 Calibre 5.1.0 转换分支 | EPUB 2 可重排，66 个正文资源及 1 个封面资源 |

转换项目：[pdf2epubEX](https://github.com/dodeeric/pdf2epubEX)、[pdf2htmlEX](https://github.com/pdf2htmlEX/pdf2htmlEX)。试用直接使用此前转换的文件，没有人工重写正文或修正图文顺序。

两份 EPUB 合计 23,695,273 字节。首次打开时异步复制到应用沙箱，每份书使用独立目录 `files/reader-trial/v1/<edition>/`；再次进入直接使用完整的本地副本，不需要下载。

## 体验方法

1. 先打开可重排版，进入「阅读设置」，点击「跳到『课堂用语』对照排版」。
2. 将字号由 22 调到 30，改变行距，检查日语断句、罗马字注音与插图位置，以及是否出现裁切、漏字和空白页。
3. 分别体验横滑与仿真翻页，检查连续操作、换章和转屏时的响应。
4. 返回后打开原版布局，用同一快捷入口定位「课堂用语」，比较图文关系和小屏可读性。
5. 离开并重新进入，确认能恢复到此前的内容和 DOM 阅读位置。两份版本的阅读进度分别保存。

「内容定位」显示 EPUB 阅读顺序中的资源序号，不将其当作原 PDF 页码。固定版转换工具生成的占位目录不适合作为教材目录，因此这里提供内容定位与已核对的课堂用语快捷入口。

## 设备与实现边界

- [华为官方说明](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/reader-introduction)：Reader Kit 要求 HarmonyOS NEXT 5.0.4 或以上的受支持真机，当前不支持模拟器。项目本身的兼容 SDK 设置仍为 26.0.0。
- 使用独立路由 `pages/NativeReaderPage`。`Index`、`ExplorePage` 及入口服务不导入 Reader Kit；点击前检查设备型号及 `BookParser`、`ReaderCore` 系统能力，避免不支持设备在应用启动时加载 `kitview`。
- EPUB 图像、CSS、内嵌字体由默认 `BookParser` 处理。初始化顺序依据[构建阅读器](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/reader-read-page)；排版尺寸取阅读组件实际区域，并换算为像素。
- 提供可重排版字号与行距、横滑/仿真翻页、内容跳转、阅读进度恢复、首屏等待与失败反馈。字体与翻页设置当前仅在本次打开期间生效。
- 固定布局的 CSS/字体兼容性、可重排版的实际显示效果、性能及原生选词体验均需真机验证。PDF 转换已丢失或打乱的注音、段落和图文关系不会仅靠更换阅读组件自动恢复。
- 这版没有接入选词查词或 AI 选择菜单；当前 Reader Kit SDK 的控制器接口未提供与现有 ArkUI `Text` 选择菜单对等的接入点，应作为方案评估的一项单独验收。

## 构建与检查

```sh
npm run build:hap
```

产物：`entry/build/default/outputs/default/entry-default-signed.hap`。

本次已通过：

- `npm run build:hap`，生成已签名 HAP。
- 两份 EPUB 的 ZIP / XML / manifest 完整性、阅读顺序资源数量、课堂用语定位，以及 HAP 中资源的字节一致性。
- HarmonyOS 7.0.0 / API 26 模拟器上的应用更新与启动；可重排、固定布局两个入口都显示不支持模拟器的提示，应用进程继续运行。

未完成：Reader Kit 真机首屏、字号重排、翻页、转屏、阅读进度恢复及交互性能验收。本次没有连接可用于 Reader Kit 验证的物理设备。构建成功及模拟器入口检查不能替代上述验证。
