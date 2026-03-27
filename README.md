# 软考高级系统架构师刷题 App

[![iOS CI](https://github.com/yljcode1/ruanKao/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/yljcode1/ruanKao/actions/workflows/ios-ci.yml)

一个面向长期学习与商业化的 SwiftUI 刷题应用脚手架，聚焦：

- 历年真题与章节题库
- 顺序 / 随机 / 模拟 / 错题重练
- 错题本与知识点掌握度
- 学习分析与薄弱项追踪
- 预留 AI 讲题、相似题生成、论文题辅导能力

## 1. 项目结构

```text
RuanKao/
├── App
│   ├── AppContainer.swift
│   ├── RootTabView.swift
│   └── RuanKaoApp.swift
├── Core
│   └── UI
│       ├── AppTheme.swift
│       └── Components
│           ├── PrimaryCard.swift
│           ├── QuestionOptionRow.swift
│           └── StatCard.swift
├── Data
│   ├── Database
│   │   ├── DatabaseMigrator.swift
│   │   └── SQLiteDatabase.swift
│   ├── Repositories
│   │   ├── SQLiteAnalyticsRepository.swift
│   │   ├── SQLiteProgressRepository.swift
│   │   └── SQLiteQuestionRepository.swift
│   └── Seed
│       └── QuestionSeedLoader.swift
├── Domain
│   ├── Models
│   │   ├── AnalyticsModels.swift
│   │   ├── PracticeMode.swift
│   │   ├── Question.swift
│   │   └── WrongQuestion.swift
│   └── Repositories
│       ├── AnalyticsRepositoryProtocol.swift
│       ├── ProgressRepositoryProtocol.swift
│       └── QuestionRepositoryProtocol.swift
├── Features
│   ├── Analytics
│   │   ├── AnalyticsView.swift
│   │   └── AnalyticsViewModel.swift
│   ├── Favorites
│   │   ├── FavoritesView.swift
│   │   └── FavoritesViewModel.swift
│   ├── Home
│   │   ├── DashboardView.swift
│   │   └── DashboardViewModel.swift
│   ├── Practice
│   │   ├── PracticeView.swift
│   │   └── PracticeViewModel.swift
│   ├── Settings
│   │   └── SettingsView.swift
│   └── WrongBook
│       ├── WrongBookView.swift
│       └── WrongBookViewModel.swift
├── Resources
│   ├── Assets.xcassets
│   ├── LaunchScreen.storyboard
│   └── Seeds
│       └── questions_seed.json
└── Support
    └── Info.plist
```

## 2. 架构设计

- **UI 层**：`SwiftUI + MVVM`
- **领域层**：题目、练习模式、错题、分析模型
- **数据层**：`SQLite3` 本地离线存储，Repository 隔离实现细节
- **依赖注入**：`AppContainer`
- **扩展思路**：
  - AI 能力接入 `AIService`
  - 云同步接入 `SyncService`
  - 付费体系接入 `SubscriptionService`

## 3. 题库模型设计

### 题目主模型

- `Question`
  - `id`
  - `year`
  - `stage`
  - `type`
  - `category`
  - `knowledgePoints`
  - `stem`
  - `options`
  - `correctAnswers`
  - `analysis`
  - `score`
  - `estimatedMinutes`

### 类型设计

- `singleChoice`：客观题
- `caseStudy`：案例分析题
- `essay`：论文题

### 为什么这样设计

- 同一套模型覆盖三类题目，减少页面分叉
- 客观题自动判分，案例/论文题支持自评
- 知识点做成数组，便于错题聚合、薄弱项统计、AI 推荐

## 4. 本地数据库设计

### 核心表

1. `questions`
2. `question_options`
3. `question_knowledge_points`
4. `attempt_records`
5. `wrong_questions`

### 关键关系

- 一道题对应多个选项
- 一道题对应多个知识点
- 一道题可产生多条作答记录
- 错题表为题目维度的聚合快照

### 适合商业化的原因

- 题库与用户行为分离，方便后续热更新题库
- 分析数据可直接用于个性化推荐
- 同步时只需上传用户行为，不必回传整库

## 5. 产品分层建议

### 免费层

- 每日精选题
- 基础顺序刷题
- 错题本基础版

### 会员层

- 全量真题与解析
- 模拟考试与成绩报告
- AI 解析 / AI 相似题 / AI 论文批改
- 多端同步
- 专属学习计划

### 增长设计

- 每日打卡
- 学习连续天数
- 阶段测评
- 分享海报
- 冲刺包 / 真题包 / 高频考点包

## 6. 后续演进建议

1. 把 `questions_seed.json` 替换为正式题库导入工具
2. 增加账号体系与 iCloud / 自建云同步
3. 对接 AI 讲题服务
4. 加入订阅、兑换码、课程联动

## 7. 当前体验优化

- 支持浅色 / 深色 / 跟随系统
- 已提供 App Icon 与 Launch Screen
- 刷题页支持章节筛选与关键词搜索
- 首页支持学习计划与历年真题入口
- 已支持题目收藏与收藏夹管理
- 已内置 AI 服务接口层，默认本地生成，配置接口后可联网调用
- 设置页可直接配置 AI 接口地址，Token 存 Keychain，适合自己先装机使用
- 题库支持多文件题包加载，后续可按年份持续扩容
- 已提供批量导入工具，可把 CSV / JSON 转成题库文件
- 首页、错题本、分析页已升级为更接近正式产品的视觉风格

## 8. 如何生成工程

当前仓库提供的是完整源码结构与 `project.yml`。

如果本机安装了 XcodeGen，可执行：

```bash
xcodegen generate
```

然后使用 Xcode 打开生成的 `RuanKao.xcodeproj`。

## 8.1 持续集成

- 已内置 GitHub Actions 流水线：`.github/workflows/ios-ci.yml`
- 触发条件：
  - push 到 `main`
  - 向 `main` 发起 Pull Request
  - 手动触发 `workflow_dispatch`
- 当前流水线会执行：

```bash
xcodebuild -project RuanKao.xcodeproj -scheme RuanKao -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## 9.1 联网说明

- **能联网**
- 当前核心刷题、错题本、学习统计都支持离线使用
- 当前联网部分主要用于 `AI 讲解 / AI 相似题 / AI 提纲`
- 你可以在 App 内 `设置 -> AI 联网` 直接填写远程接口地址
- 如果不填，系统会自动回退到本地 AI 模拟，不影响刷题
- 建议使用 `HTTPS POST`
- 支持三种接入方式：
  - 自定义接口：直接接收下面这份 JSON
  - OpenAI / DeepSeek 兼容接口：地址可填 `https://api.openai.com/v1`、`https://api.openai.com/v1/chat/completions`、`https://api.deepseek.com/v1`
  - `Responses API` 中转站：地址可填 `https://aixj.vip`、`https://aixj.vip/v1`、`https://aixj.vip/v1/responses`
- 如果使用 OpenAI / DeepSeek / `Responses API`：
  - Token 填你自己的 API Key
  - 模型建议填写；不填时，OpenAI 默认 `gpt-4.1-mini`，DeepSeek 默认 `deepseek-chat`
  - 如果你的中转站走 `chat/completions`，建议直接填完整 `/v1/chat/completions`
  - 如果你的中转站走 `responses`，可以直接填根地址或 `/v1`
- 当前自定义接口入参为：

```json
{
  "style": "explanation",
  "question": { }
}
```

- 当前远程接口返回示例：

```json
{
  "title": "这道题考什么",
  "summary": "核心思路总结",
  "highlights": ["要点 1", "要点 2"],
  "nextAction": "下一步怎么学",
  "source": "你的 AI 服务名"
}
```

## 10. 安装到 iPhone

详细步骤见：

- `INSTALL_ON_IPHONE.md`

## 11. 批量扩充题库

- 导入说明：`/Users/yaolijun/Documents/iphoneApp/ruanKao/QUESTION_IMPORT.md`
- 导入工具：`/Users/yaolijun/Documents/iphoneApp/ruanKao/Tools/question_importer.swift`
- 模板目录：`/Users/yaolijun/Documents/iphoneApp/ruanKao/Templates`
