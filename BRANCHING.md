# Branching Strategy

本仓库采用企业常见的 `master / develop / test` 三主干模型，目标是把 **发布稳定性**、**测试验证** 和 **日常开发** 分开。

## 分支职责

### `master`

- 只保留**可发布/已发布**代码
- 只接受来自 `test` 或 `hotfix/*` 的合并
- 不作为日常开发分支

### `develop`

- 作为**默认开发分支**
- 日常功能开发统一从这里切出 `feature/*`
- 所有准备进入下一版本的改动先汇总到这里

### `test`

- 作为**测试集成分支**
- 接收来自 `develop` 的待测代码
- 用于联调、提测、回归验证
- 验证稳定后再合并到 `master`

### `feature/*`

- 例如：`feature/question-bank-boost`
- 从 `develop` 切出
- 完成后通过 Pull Request 合并回 `develop`

### `release/*`

- 例如：`release/v1.1.0`
- 从 `test` 切出
- 只允许做发版收尾：版本号、文案、回归修复
- 验证通过后合并到 `master`，并回合到 `develop` / `test`

### `hotfix/*`

- 例如：`hotfix/login-crash`
- 从 `master` 切出
- 用于线上紧急修复
- 修复后同时合并回 `master`、`test` 和 `develop`

## 推荐流程

### 新功能开发

1. 从 `develop` 切出 `feature/*`
2. 开发完成后提 PR 到 `develop`
3. CI 通过后合并

### 测试提测

1. 从 `develop` 切出 `release/*`
2. 或直接从 `develop` 提 PR 到 `test`
3. 在 `test` 上完成联调、测试和回归

### 版本发布

1. 从 `test` 提 PR 到 `master`
2. 做发布前最终确认和必要修复
3. PR 合并到 `master`
4. 打 Tag / 创建 GitHub Release
5. 如有发布收尾改动，再回合并到 `develop` / `test`
6. 标准发版清单见 `RELEASE.md`

### 紧急修复

1. 从 `master` 切出 `hotfix/*`
2. 修复并验证
3. PR 合并到 `master`
4. 同步回 `test` 和 `develop`

## 规则约束

- `master`、`develop`、`test` 必须开启保护
- 禁止直接向 `master` 推送
- 关键分支必须通过 PR 合并
- 合并前必须通过 CI
- 分支命名统一使用：
  - `feature/*`
  - `release/*`
  - `hotfix/*`
  - `chore/*`
  - `fix/*`

## 当前仓库约定

- 默认开发分支：`develop`
- 测试分支：`test`
- 发布分支：`master`
- 当前 CI 检查名：`build`
- Release PR 模板：`.github/PULL_REQUEST_TEMPLATE/release_to_master.md`
