# 安装到你的 iPhone

这个项目已经整理成可生成 Xcode 工程的结构。你自己使用时，不需要上架 App Store。

## 前提

1. 一台 Mac
2. 一台 iPhone
3. 你的 Apple ID
4. 完整版 Xcode（不是 Command Line Tools）

## 第 1 步：安装 Xcode

在 App Store 安装 `Xcode`，安装完成后先打开一次。

如果终端里执行下面命令返回的不是 Xcode 路径，需要切换：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

再执行：

```bash
xcodebuild -version
```

正常会看到 Xcode 版本号。

## 第 2 步：生成工程

如果你还没安装 `xcodegen`：

```bash
brew install xcodegen
```

进入项目目录：

```bash
cd /Users/yaolijun/Documents/iphoneApp/ruanKao
```

生成 Xcode 工程：

```bash
xcodegen generate
```

成功后会得到：

```text
RuanKao.xcodeproj
```

## 第 3 步：打开工程并设置签名

双击打开：

```text
/Users/yaolijun/Documents/iphoneApp/ruanKao/RuanKao.xcodeproj
```

然后在 Xcode 里：

1. 选中左侧 `RuanKao` 项目
2. 选中 `TARGETS -> RuanKao`
3. 打开 `Signing & Capabilities`
4. 勾选 `Automatically manage signing`
5. `Team` 选择你的 Apple ID 对应的 `Personal Team`
6. 如果报 `Bundle Identifier` 冲突，就改成你自己的唯一值，例如：

```text
com.yaolijun.ruankao
```

## 第 4 步：连接 iPhone

用数据线连接 iPhone 到 Mac。

第一次真机调试时需要：

1. 在 iPhone 上信任这台 Mac
2. 打开 iPhone 的“开发者模式”

路径通常是：

```text
设置 -> 隐私与安全性 -> 开发者模式
```

开启后手机会重启一次。

## 第 5 步：运行到手机

在 Xcode 顶部设备列表里选择你的 iPhone，然后点击运行按钮。

首次运行常见情况：

- Xcode 会自动完成签名和安装
- 如果提示“Untrusted Developer”，去手机设置里信任开发者

路径通常是：

```text
设置 -> 通用 -> VPN 与设备管理
```

## 第 6 步：如果你想开通联网 AI

App 装到手机后，打开：

```text
App 首页 -> 右上角设置 -> AI 联网
```

然后填写：

1. `接口地址`：建议填 `HTTPS` 地址
2. `访问令牌`：如果你的 AI 服务需要鉴权就填，不需要可以留空
3. `模型（可选）`：如果你接 OpenAI / DeepSeek 兼容接口，建议填模型名；不填时 OpenAI 默认 `gpt-4.1-mini`，DeepSeek 默认 `deepseek-chat`

常见填写方式：

- OpenAI：
  - `接口地址`：`https://api.openai.com/v1`
  - `访问令牌`：你的 OpenAI API Key
  - `模型（可选）`：`gpt-4.1-mini`
- DeepSeek：
  - `接口地址`：`https://api.deepseek.com/v1`
  - `访问令牌`：你的 DeepSeek API Key
  - `模型（可选）`：`deepseek-chat`
- 自定义接口：
  - 填你自己的服务地址
  - 请求体需兼容本 App 的 `style + question`

说明：

- 刷题、错题本、学习统计本身都是离线可用
- 联网主要用于 AI 讲解、AI 相似题、AI 提纲
- 不配置接口也能正常用，系统会自动退回本地 AI 模拟结果
- 填完后可以先点 App 内的 `测试连接`，成功后再点 `保存配置`

## 常见问题

### 1. 提示没有 Xcode

说明当前只装了命令行工具，没有完整 Xcode。先安装 Xcode，再执行：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 2. 提示 Signing 失败

通常是：

- 没登录 Apple ID
- 没选 `Personal Team`
- `Bundle Identifier` 和别人重复

### 3. App 打不开或 7 天后失效

如果你用的是免费 Apple 账号的 `Personal Team`，真机调试证书有时限，过期后重新连接 Xcode 运行一次即可。

## 当前项目里你需要关注的文件

- 工程配置：`/Users/yaolijun/Documents/iphoneApp/ruanKao/project.yml`
- 应用入口：`/Users/yaolijun/Documents/iphoneApp/ruanKao/RuanKao/App/RuanKaoApp.swift`
- 安装说明：`/Users/yaolijun/Documents/iphoneApp/ruanKao/INSTALL_ON_IPHONE.md`
