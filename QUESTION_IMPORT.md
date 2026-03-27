# 题库批量导入

现在题库支持 **多文件题包**。你可以把从网页、PDF、Excel 整理出来的题目，转换成 CSV 或 JSON 后批量导入。

## 1. 准备模板

- CSV 模板：`/Users/yaolijun/Documents/iphoneApp/ruanKao/Templates/questions_import_template.csv`
- JSON 模板：`/Users/yaolijun/Documents/iphoneApp/ruanKao/Templates/questions_import_template.json`

推荐做法：

1. 先把网上真题整理进 Excel
2. 导出成 CSV
3. 用导入工具转成 App 可识别的题包 JSON

## 2. 执行导入

```bash
cd /Users/yaolijun/Documents/iphoneApp/ruanKao
swift /Users/yaolijun/Documents/iphoneApp/ruanKao/Tools/question_importer.swift \
  --input /你的题库/questions_2025.csv \
  --output /Users/yaolijun/Documents/iphoneApp/ruanKao/RuanKao/Resources/Seeds/Imports/questions_2025.json
```

也可以直接导入 JSON：

```bash
swift /Users/yaolijun/Documents/iphoneApp/ruanKao/Tools/question_importer.swift \
  --input /你的题库/questions_2025.json \
  --output /Users/yaolijun/Documents/iphoneApp/ruanKao/RuanKao/Resources/Seeds/Imports/questions_2025.json
```

## 3. 导入后怎么生效

执行完成后：

```bash
cd /Users/yaolijun/Documents/iphoneApp/ruanKao
xcodegen generate
```

然后重新用 Xcode 运行 App 到 iPhone。

当前 App 启动时会自动同步所有 `Seeds` 目录下的题包：

- 初始题库：`questions_seed.json`
- 你新增的题包：`Seeds/Imports/*.json`

所以你后面扩题时，不需要手动改数据库结构。

## 4. 字段说明

- `id`：可留空；导入器会根据 `year + stage + type + stem` 自动生成稳定 ID
- `year`：年份
- `stage`：如 `上午真题`、`下午案例`、`论文题`
- `type`：支持 `singleChoice` / `caseStudy` / `essay`
- `category`：如 `架构设计`、`操作系统`、`网络`
- `knowledge_points`：多个知识点可用 `|` 分隔
- `correct_answers`
  - 选择题：如 `B` 或 `A|C`
  - 案例 / 论文：直接填参考答题要点
- `options_json`：JSON 模式下可直接传选项数组
- `option_a` ~ `option_f`：CSV 模式下可分别填写选项

## 5. 当前建议

如果你是自己用，我建议按这个顺序补库：

1. 先补近 5 年真题
2. 再补高频章节题
3. 最后补论文题素材和优秀提纲
