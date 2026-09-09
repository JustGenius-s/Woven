# 教材源码整理与恢复

2026-09-09 将已被替换的模板转换流程归档。当前全书源码、原版阅读、Reader Kit 接入及其资源均保留。

## 保留内容

- `content/reader-semantic-full/book.cjs` 和 `content/reader-semantic-trial/book.json`：当前全书与第 11、17 页基准。
- `scripts/rebuild-reader-semantic-full.cjs`、`scripts/rebuild-reader-semantic-trial.cjs` 及其所有依赖模块。
- `scripts/build-reader-web.cjs`：精简为当前全书生成入口，不再加载旧模板和旧教材 JSON。
- 所有 ArkTS 阅读页面、服务、章节元数据、原版 EPUB、当前语义 ZIP、两份 Reader Kit EPUB 基线。
- 全书、两页基准、旧样本和旧全书预览：仍在 `docs/previews/` 原路径，可继续查看。
- 提取缓存与已签名 HAP：不清理、不重置。

预览、语义模型、转换记录和导出配置可重新生成，由 `.gitignore` 排除。
全书导出配置改为 `docs/previews/reader-semantic-full-config.json`；手工维护的源配置仍是 `book.cjs`。
应用必需的 ZIP、EPUB 和生成 ArkTS 元数据不忽略。

## 归档内容

- `content/reader-full/`、`content/reader-sample/`、`content/reader-common/`：旧版及样本教材配置、旧样式。
- `author-reader-full.cjs`、`build-reader-book.cjs`、`extract-reader-source.cjs`、`rebuild-reader-reflow.cjs`、`rebuild-reader-sample.cjs`。
- `scripts/lib/reader-book/` 下旧流程专用的 `index.cjs`、`source.cjs`、`templates.cjs`、`package.cjs`、`artwork-pdf.cjs`。
- 原 `build-reader-web.cjs` 两页覆盖实现，以及整理前的文档和生成配置。

## 本地恢复快照

快照位置：`.archives/reader-cleanup-20260909-032540.zip`。
清单位置：`.archives/reader-cleanup-20260909-032540.json`，ZIP 内也有 `CLEANUP-MANIFEST.json`。

归档前保留了当前教材管线、源配置、预览、阅读代码和教材资源的副本。
每个文件记录相对路径、字节数、SHA-256 及本次处理类型（归档、修改或保留），归档内容已逐项核对。
归档不包含签名配置和凭据。`.archives/` 不参与构建，也不纳入源码管理；需要跨电脑保留时另行复制此 ZIP。

恢复时先解压到新建的空目录，按清单查看需要取回的文件，再选择性复制。
不要直接覆盖当前工程：快照也包含整理前的文件版本。旧版脚本的路径依赖按原工程相对路径保留。
如需重新生成旧 EPUB，使用快照里的旧生成器与内容配置，并提供原 PDF 和对应依赖。

此次不运行测试，不自行查看排版效果；仅核对引用和文件完整性，并重新生成当前书籍确认内容未改变。

整理完成后的全书生成成功，ZIP 内 374 个条目的内容与清理前一致。
重新压缩只改变了目录时间戳；核对内容后保留原 ZIP 与缓存版本，避免无意义的资源版本变化。
清单中 39 个受保护文件（包括当前渲染源码、配置、阅读代码、预览和教材资源）及原签名 HAP 的 SHA-256 均保持不变。
