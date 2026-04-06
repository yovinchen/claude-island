# Claude Island 额度查询现状分析

更新日期：2026-04-06

## 目标

本文档用于明确 `Claude Island` 当前已经具备的 usage / quota 能力、相对 `CodexBar` 缺失的部分、可直接复用的接入方案，以及首个可发布版本的实现边界。

## 当前项目已支持的内容

### 1. 会话级 usage 展示已经上线

- Hook 事件里的 `rate_limits` 已经会进入 [UsageDataManager.swift](/Users/yovinchen/project/claude-island/ClaudeIsland/Services/Usage/UsageDataManager.swift)。
- 当前会把 `primary`、`secondary`、`contextWindow` 聚合到 `UsageData`。
- Notch 头部已经会显示 usage ring，入口在 [UsageRing.swift](/Users/yovinchen/project/claude-island/ClaudeIsland/UI/Components/UsageRing.swift) 和 [NotchView.swift](/Users/yovinchen/project/claude-island/ClaudeIsland/UI/Views/NotchView.swift)。
- Settings 里已有一个 usage 开关，但仅控制 ring 是否显示，不是账号额度页。

### 2. 账号级 quota 域模型已经存在

- 仓库已有 `Quota` 目录，包含：
  - `QuotaStore`
  - `QuotaProviderProtocol`
  - `QuotaSecretStore`
  - `QuotaModels`
  - `QuotaUtilities`
- 这些代码已经能通过当前 Xcode 工程编译。
- `QuotaStore` 已经具备：
  - provider record 管理
  - enable/disable 持久化
  - refresh loop
  - snapshot / diagnostics 状态
  - header summary 排序能力

### 3. 当前 quota scaffold 已覆盖 8 个 provider

当前 `QuotaProviderID` 已包含：

- Codex
- Claude
- Gemini
- Kiro
- OpenRouter
- Warp
- Kimi K2
- z.ai

这 8 个 provider 与本次首波实现目标完全一致。

### 4. 当前会话监控生态已经很广

`SessionSource` 当前已覆盖：

- Claude / Cline / Codex CLI / Codex Desktop
- Cursor / OpenCode / Gemini / Copilot
- CodeBuddy / Qoder / Droid / Windsurf
- Kimi CLI / Kiro CLI / Amp CLI
- Pi / Crush / Trae

这意味着 `Claude Island` 已经有了“多工具监控”的产品基础，只差“账号额度层”没有补上。

## 当前缺失内容

### 1. Quota provider 仍然全部未接线

- [QuotaProviders.swift](/Users/yovinchen/project/claude-island/ClaudeIsland/Quota/Providers/QuotaProviders.swift) 当前所有 provider 都是 `UnsupportedQuotaProvider`。
- 也就是说：
  - 没有真实 fetcher
  - 没有 OAuth / API key / CLI 读取逻辑
  - 没有 parser
  - 没有 provider-specific metadata

### 2. Quota store 没有进入应用生命周期

- 应用启动流程 [AppDelegate.swift](/Users/yovinchen/project/claude-island/ClaudeIsland/App/AppDelegate.swift) 里没有启动 `QuotaStore.shared.start()`。
- 应用退出时也没有停止 quota refresh loop。
- App 重新激活时也不会触发额度刷新。

### 3. Settings 没有 provider-first 的额度配置界面

- 当前 `Usage` tab 只有：
  - 一个 `showUsageData` toggle
  - 一段 usage ring 描述文案
- 当前缺少：
  - provider 列表
  - enabled/disabled 状态
  - account / plan / credits / windows 详情
  - API key 输入
  - dashboard / status 跳转
  - 手动 refresh
  - 错误诊断

### 4. Notch 没有完整额度详情页

- 现有 `NotchContentType` 只有：
  - `instances`
  - `menu`
  - `chat`
  - `approval`
  - `hookSetup`
  - `onboarding`
- 缺少：
  - 独立 quota 面板
  - header risk summary
  - 从 Notch menu 进入额度页的入口

### 5. 缺少测试目标

- 当前仓库没有 `ClaudeIslandTests` target。
- 这意味着 quota parser、store 排序、Settings/Notch quota 视图都没有自动回归保护。

## 与 CodexBar 的差异对比

### CodexBar 已具备的能力

`CodexBar` 已经有：

- provider metadata / descriptor 体系
- provider-specific fetch strategy
- provider settings pickers / toggles / secure fields
- provider detail pane
- menu card / overview / merge display
- 多种凭据来源
- 更成熟的错误展示与刷新路径

参考代码：

- [PreferencesProvidersPane.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/PreferencesProvidersPane.swift)
- [PreferencesProviderDetailView.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/PreferencesProviderDetailView.swift)
- [ProviderImplementation.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/Providers/Shared/ProviderImplementation.swift)
- [ProviderImplementationRegistry.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/Providers/Shared/ProviderImplementationRegistry.swift)

### Claude Island 当前更适合的方式

`Claude Island` 不适合直接照搬 `CodexBar` 的整套 UI，因为：

- 产品重心是 Notch + 快速交互，不是 menu bar app
- 现有 UI 结构更轻量
- 当前没有独立的 Core target / provider runtime 架构
- 当前项目更适合“最小移植数据来源 + 重新设计 Claude Island 风格 UI”

因此建议：

- 参考 `CodexBar` 的 provider 数据来源和 parser
- 不直接迁移 `CodexBar` 的复杂 UI / 状态管理框架
- 在 `Claude Island` 内保留：
  - `QuotaStore` 作为统一状态层
  - Settings 的 provider-first pane
  - Notch 的压缩版 quota panel

## 首版可接入方案

### Wave 1：现有 8 个 provider

#### Codex

- 主路径：`~/.codex/auth.json` OAuth
- 兜底：`codex app-server` JSON-RPC
- 数据：
  - session / weekly window
  - credits
  - email / plan

#### Claude

- 主路径：Keychain `Claude Code-credentials` 或 `~/.claude/.credentials.json`
- 数据：
  - session / weekly / sonnet window
  - account / plan
  - optional extra usage 信息

#### Gemini

- 路径：`~/.gemini/oauth_creds.json`
- API：`retrieveUserQuota`
- 数据：
  - Pro / Flash / Flash Lite 三组 quota
  - email / tier

#### Kiro

- 路径：`kiro-cli chat --no-interactive /usage`
- 数据：
  - credits
  - bonus credits
  - reset 信息

#### OpenRouter

- 路径：环境变量或 Keychain 中保存的 API key
- 数据：
  - credits
  - key quota
  - balance

#### Warp

- 路径：环境变量或 Keychain 中保存的 API key
- 数据：
  - credits
  - add-on credits
  - next refresh

#### Kimi K2

- 路径：环境变量或 Keychain 中保存的 API key
- 数据：
  - consumed / remaining credits

#### z.ai

- 路径：环境变量或 Keychain 中保存的 API key
- 数据：
  - tokens window
  - MCP / time window
  - plan
- 首版保留 region picker

## 首版 UI 方向

### Settings

将当前 `Usage` tab 升级为 `Usage & Quota`：

- 顶部：
  - `Show session usage rings` 开关
  - `Refresh all` 按钮
  - `Last updated` 文案
  - 高风险 quota overview cards
- 左侧：
  - provider 列表
  - enabled/disabled
  - 摘要状态
- 右侧：
  - provider detail
  - primary / secondary windows
  - credits
  - account / plan / source / updated
  - secure token input 或 setup guidance
  - dashboard / status 按钮
  - error diagnosis

### Notch

新增独立 quota 内容态：

- header：
  - 继续保留 session usage ring
  - 新增最多 3 个高风险 quota chip
- menu：
  - 新增 `Quota` 入口
- panel：
  - provider cards
  - primary / secondary progress
  - credits / account / last updated
  - refresh / dashboard 操作

## 不进入首版的内容

以下内容不作为首个可发布版本阻塞项：

- Codex / Claude web extras
- usage breakdown / credits history 图表
- 历史 pace 分析
- Wave 2 与 Wave 3 provider 全量扩展
- 完整复刻 CodexBar 的多账号 / overview / merged switcher 模式

## 结论

`Claude Island` 当前最关键的事实是：

- 会话 usage 已经有了
- 账号 quota scaffold 已经有了
- Wave 1 的 provider enum 也已经有了
- 真正缺的是 provider fetcher、应用接线、Settings pane、Notch panel、测试目标

因此本次实现应以“完成 Wave 1 的 8 个 provider + Settings/Notch 两边完整可用”为首个里程碑，而不是直接追平 `CodexBar` 的所有 provider 和所有高级特性。
