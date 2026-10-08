# Irodori 入门课程重排

入门教材的教室用语及第 1–18 课在文法课程列表中打开重排阅读器。课程顺序、课程标题和音频沿用原教材；原 PDF 源文件及既有缓存保留，不支持 Reader Kit 的设备继续打开 PDF。第 1 课使用已经确认的独立版本，其 EPUB 不由批量脚本覆盖。

## 生成与检查

输入为官方中文 Starter 教材目录，包含 `X_kyoshitsu_CN.pdf` 和各课 `X_LNN_CN*.pdf`。原 PDF 不入库。需要 Python（PyMuPDF、Pillow、numpy、fontTools）与 Node.js（pdfjs-dist、playwright）。原字体缓存绑定源文件 SHA-256；首次构建前使用 `extract-fonts.cjs` 为每课提取字体，输出到 `.cache/irodori-starter/fonts-lNN`（教室用语为 `fonts-l00`）。例如第 2 课：

```sh
node scripts/lib/irodori/extract-fonts.cjs /path/to/X_L02_CN_230727a.pdf .cache/irodori-starter/fonts-l02
```

```sh
python3 scripts/build-irodori-starter.py /path/to/教材 --lessons 0,2-18
python3 scripts/verify-irodori-starter.py
node scripts/preview-irodori-starter.cjs --browser /path/to/chromium
# 完成视觉核对后，更新应用资源、课程注册表及内容审计记录：
python3 scripts/verify-irodori-starter.py --publish
```

生成物先写入 `.cache/irodori-starter/`；普通构建不会覆盖应用资源。`--publish` 验证全部 18 个新增条目后，将 EPUB 复制到 `rawfile/reader`，生成 `IrodoriStarterContent.ets` 及 `IRODORI_STARTER_AUDIT.json`。每个 EPUB 的哈希决定缓存和阅读进度版本。

## 排版原则

- 正文使用原 PDF 内嵌字体，保留颜色、字号比例及汉字注音；页面按原 PDF 页序组织，手机一屏不等于原 PDF 一页。
- 汉字练习把同一个词的三种字形放在同一行；假名表、数字表等使用可分页表格。
- 词汇图片及标签成组排列。地图、路线图、带插图的答题表格及语法关系图保留局部原图，避免箭头、选项或标注错位。这些局部图中文字随图片缩放，不跟随正文字号单独变大。
- `starter_art_regions.json` 记录需人工确认的复杂图组边界。PDF 图形提取尊重裁剪区域，避免不可见路径误吞正文。
- 页眉装饰、照片、插画和音频标记沿用原稿；版权署名保留。没有使用整页截图代替全篇重排。

## 验证范围

新增范围为教室用语及第 2–18 课，共 446 个原 PDF 页面；加上既有第 1 课的 18 页，入门教材共 464 页。

生成时逐页检查正文非空字符的唯一归属，并比较输出文字与图像替代文本，遗漏或重复会失败。打包检查覆盖所有 spine、资源引用和实际使用的原字体字形，逐页核对活文字字符数与图像字符数之和。浏览器检查验证字体、图片加载及手机宽度下的横向溢出；输出记录绑定 EPUB 哈希，避免把旧预览当作新版本结果。

字符审计不能验证图文关系，仍需看图核对；浏览器预览不能替代 Reader Kit 实机检查。重排页沿用音频选曲、播放、进度和退出释放逻辑，暂不提供原 PDF 页面的实时讲解入口。

当前发布资源的新增正文共 219,619 个非空字符，其中 176,397 个为嵌入原字体的活文字，43,222 个位于局部原图；167 个原生表格。18 个新增 EPUB 合计 94,624,925 字节。全部 446 页最终浏览器检查通过，检查记录的 EPUB 哈希与发布文件一致。第 1 课文件 SHA-256 仍为 `b9686cd170287c1df2a79ee4326ea510e8294d020649b6f956a42388fcc6734d`。

2026-10-08 在连接的 HarmonyOS 手机安装最终 HAP，核对包内 19 个入门 EPUB 均与仓库资源一致。实机抽查覆盖教室用语两页图组、第 2 课假名表与音频播放、第 13 课路线图、第 18 课汉字三种字形和文化正文；验证章节跳转及阅读进度恢复。实机为代表页抽查，并未逐屏检查全部课程。Reader Kit 分页与浏览器不同，个别页尾版权行仍可能单独占屏，留下较多空白；正文和图片内容均保留。
