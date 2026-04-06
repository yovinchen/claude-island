# Claude Island 额度查询实施计划

更新日期：2026-04-06

## 目标

完成 `Claude Island` 的首个可发布额度查询版本：

- Wave 1 的 8 个 provider 可用
- Settings 具备 provider-first 的额度配置与详情能力
- Notch 具备风险摘要与独立 quota 面板
- 基础测试目标落地

## Wave 1 范围

本次实现范围固定为以下 8 个 provider：

- Codex
- Claude
- Gemini
- Kiro
- OpenRouter
- Warp
- Kimi K2
- z.ai

## 实施步骤

### 1. 文档基线

- 新建：
  - `docs/quota-query-analysis.md`
  - `docs/quota-query-plan.md`
- 固化：
  - 当前仓库现状
  - 与 CodexBar 的能力对比
  - Wave 1 / Wave 2 / Wave 3 的边界
  - UI 方向与验证项

### 2. Quota 领域层补齐

- 扩展 `QuotaProviderDescriptor`，补齐：
  - primary / secondary label
  - dashboard URL
  - status URL
  - credential placeholder
  - sort priority
- 为 8 个 Wave 1 provider 实现真实 fetcher
- 为 `QuotaStore` 增加：
  - `refreshIfNeeded`
  - 用户可见刷新触发
  - refresh 状态保护

### 3. 应用生命周期接线

- 在 `AppDelegate` 启动时：
  - `QuotaStore.shared.start()`
- 在 `AppDelegate` 退出时：
  - `QuotaStore.shared.stop()`
- 在应用重新激活时：
  - 若数据超过 60 秒未刷新，则触发 `refreshIfNeeded`

### 4. Settings 额度页

- 将现有 `Usage` tab 升级为 `Usage & Quota`
- 页面结构：
  - overview summary
  - session usage ring toggle
  - 左侧 provider list
  - 右侧 detail pane
- detail pane 统一展示：
  - provider name
  - enabled toggle
  - source / state / updated
  - account / plan / credits
  - primary / secondary window
  - error section
  - refresh / dashboard / status
  - secure token field 或 setup instruction

### 5. Notch 额度体验

- 新增 `NotchContentType.quota`
- 在 Notch header 显示：
  - top risk quota chips
- 在 Notch menu 增加：
  - `Quota` row
- 新增 `QuotaPanelView`：
  - 压缩卡片布局
  - refresh / dashboard 操作
  - account / credits / error / windows 信息

### 6. 测试目标

- 新增 `ClaudeIslandTests` target
- 将 test target 挂到共享 scheme 的 test action
- 首批测试覆盖：
  - `QuotaUtilities`
  - `QuotaStore`
  - Wave 1 parser / fetcher
  - Settings / Notch 的关键排序与空态逻辑

## 验证标准

### 功能验证

- Settings 中可查看 8 个 Wave 1 provider
- 可输入并保存 API key 型 provider 的凭据
- 可看到：
  - state
  - source
  - updated
  - account / plan
  - credits / windows
- 可手动刷新
- 可从 Notch menu 进入 quota panel
- Notch header 能显示高风险 quota 摘要

### 工程验证

- `xcodebuild -project ClaudeIsland.xcodeproj -scheme ClaudeIsland -configuration Debug CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build`
- 新增测试 target 可运行
- quota 相关改动不影响现有 session monitoring / approval / chat 功能编译

## 后续阶段

### Wave 2

在 Wave 1 稳定后扩展：

- Cursor
- Kimi
- Copilot
- OpenCode
- Amp
- Augment
- JetBrains AI

### Wave 3

后续独立排期：

- Alibaba
- MiniMax
- Factory
- Kilo
- Vertex AI
- Ollama
- Perplexity
- Antigravity
- Synthetic

## 默认原则

- 参考 `CodexBar` 的数据来源，不直接照搬其整套架构
- 首版以“可稳定使用”为先，不追图表和高级 web extras
- UI 保持 `Claude Island` 的轻量、卡片化、Notch 友好风格
- 优先复用现有 `QuotaStore`，避免引入第二套并行状态层
