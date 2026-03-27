# Release Workflow

本文件用于规范仓库的 **`test -> master`** 发布流程，适合作为发版负责人、测试负责人和开发负责人共同使用的标准清单。

## 适用范围

- 正常版本发布：`test` -> `master`
- 预发布整理：必要时从 `test` 切 `release/*`
- 紧急线上修复：走 `hotfix/*`，不使用本清单

## 标准流程

### 1. 提测完成

- `develop` 改动已经合入 `test`
- `test` 已完成联调、冒烟、回归
- 当前版本不再接受非必要改动

### 2. 发版前确认

- 确认版本号 / Build 号已经更新
- 确认 CI `build` 通过
- 确认关键页面、登录、练题、错题本、收藏等核心路径可用
- 确认发版说明、已知风险、回滚方案已准备

### 3. 发起 Release PR

- Source Branch：`test`
- Target Branch：`master`
- 使用模板：`.github/PULL_REQUEST_TEMPLATE/release_to_master.md`

如需发版冻结，可先从 `test` 切 `release/vx.y.z`，只允许做：

- 版本号调整
- 文案修正
- 回归缺陷修复
- Release Notes 整理

### 4. 合并发布

- PR 审核通过
- 所有必需检查通过
- 合并到 `master`
- 打 Tag：`vX.Y.Z`
- 创建 GitHub Release

### 5. 发布后回合并

- 若发布过程中有额外修复，必须同步回 `develop`
- 如 `test` 上仍要继续承接验证，也要同步回 `test`

## 推荐命令

```bash
git switch test
git pull origin test
git switch -c release/v1.0.1
```

发版 PR 合并后：

```bash
git switch master
git pull origin master
git tag v1.0.1
git push origin v1.0.1
```

## Release PR 必填项

- 版本号 / Tag
- 发布类型（正式版 / 补丁版）
- 包含功能与修复摘要
- 测试范围与结果
- 已知风险
- 回滚方案
- 发布负责人

## GitHub Release 建议结构

### Highlights

- 本版本最重要的功能或改进

### Fixes

- 关键问题修复列表

### Risks

- 已知限制

### Upgrade Notes

- 需要额外关注的升级说明
