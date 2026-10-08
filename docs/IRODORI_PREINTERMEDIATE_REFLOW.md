# Irodori 初中级课程重排

范围为初中级第 1–18 课，使用 `04_初中級_PreIntermediate_A2-B1/教材/ZZ_L01.pdf` 至 `ZZ_L18.pdf`。合订本、封面、前言、目录、自评表和版权页不重复导入课程。

2026-10-08 转换完成：18 个 EPUB、571 个原 PDF 页面，合计 92,115,510 字节。课程注册表已接入文法入口，随后按用户要求编译成功并覆盖安装到手机，保留应用数据。

沿用用户指定的“只转换，由用户手工验证”流程。未进行字符审计、字体导出复核、EPUB 验证、浏览器预览、测试或手机排版检查。转换记录标记 `verification: not_run`。

## 转换命令

```sh
python3 scripts/build-irodori-elementary.py /path/to/IRODORI --levels 3 --node /path/to/node --jobs 3
```

复用初级的原字体、注音、表格及图文转换流程，停用入门专用页码和人工裁图坐标；复杂图组自动推断边界，无法导出为文字的字形保留为局部图像。此次仅重排原稿，不增加翻译。

`--levels 3` 只处理初中级，不重写入门、初级 1 或初级 2 的教材及课程注册表。脚本默认 `--levels 1,2` 仍只处理初级。中断后，输入和转换规则未变化时可用 `--resume` 继续。

字体缓存、逐课转换记录和日志位于 `.cache/irodori-elementary/a2b1/`，汇总位于 `.cache/irodori-elementary/conversion-levels-3.json`，均不纳入 Git。

## 应用接入

转换输出为 `entry/src/main/resources/rawfile/reader/irodori-a2b1-lNN-reflow.epub`，注册表为 `IrodoriPreIntermediateContent.ets`。文法入口继续使用现有课程 ID `irodori-a2b1-lNN` 和课程音频；原 PDF 及不支持 Reader Kit 的设备回退入口保留。

阅读设置中的“第 n 页”对应原 PDF 页码。手工反馈可注明初中级、课号和原页码。
