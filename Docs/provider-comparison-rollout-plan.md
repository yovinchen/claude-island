# Provider Comparison Rollout Plan

## Goal

把 `Claude Island` 的 provider 能力按模块、按 provider、按顺序对齐到 `CodexBar` 的后端能力。

这份计划不是泛泛的“后续可以做什么”，而是：

1. 逐个 provider 对比当前状态
2. 明确缺什么
3. 标出参考文件
4. 给出实现顺序
5. 给出完成标准

## Current Rollout Status

### Already landed

- `Codex`
  - OAuth usage 兼容增强
  - config-based usage URL 选择
  - CLI fallback
- `Claude`
  - OAuth usage
  - CLI PTY `/usage` + `/status` 基础路径
- `Gemini`
  - OAuth quota
- `Kiro`
  - CLI `/usage`
- `Cursor`
  - manual cookie mode
- `OpenCode`
  - manual cookie mode
- `Amp`
  - manual cookie mode
- `Augment`
  - manual cookie mode
- `Copilot`
  - API token mode
- `Kimi`
  - auth token mode
- `JetBrains AI`
  - local quota file mode
- `OpenRouter`
  - API key mode
- `Warp`
  - API key mode
- `Kimi K2`
  - API key mode
- `z.ai`
  - API key mode

### Still missing across the board

- browser cookie auto import
- cookie source state machine (`auto / manual / off`)
- provider runtime keepalive / failure recovery
- provider debug probe surface
- richer provider version/runtime detection
- per-provider live validation and diagnostics

## Shared Foundation Checklist

这些不是单个 provider 的工作，而是后续多 provider 都要依赖的基础层。

- [ ] `Provider source planner`
  - 目标：
    - 从“fetcher 直接决定路径”升级为“先选 source，再执行 fetch”
  - 参考：
    - [ProviderFetchPlan.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/ProviderFetchPlan.swift)
    - [UsageFetcher.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/UsageFetcher.swift)

- [ ] `Provider debug probe`
  - 目标：
    - 每个 provider 都至少能输出“当前 source、关键请求上下文、最近错误”
  - 参考：
    - [UsageStore.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/UsageStore.swift)
    - `debugRawProbe` 分布于 `CodexBarCore/Providers/*`

- [ ] `Per-provider CLI version detection parity`
  - 目标：
    - 每个 CLI 型 provider 都能稳定展示：
      - binary 是否存在
      - 真实版本号
      - 来自 PATH 还是 override path
    - provider-specific version parse 不再只依赖通用 `--version`
  - 参考：
    - [ProviderCLIConfig.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/ProviderCLIConfig.swift)
    - [ProviderVersionDetector.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/ProviderVersionDetector.swift)
    - [PathEnvironment.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/PathEnvironment.swift)

- [ ] `Provider runtime layer`
  - 目标：
    - 为会话型 / cookie型 provider 增加 keepalive / force refresh / failure recovery
  - 参考：
    - `Providers/*/*ProviderRuntime.swift`

- [ ] `Browser cookie infrastructure`
  - 目标：
    - browser detection
    - cookie import order
    - cookie validation
    - source-aware cache
  - 参考：
    - [Package.swift](/Users/yovinchen/project/CodexBar/Package.swift)
    - `SweetCookieKit`
    - `BrowserCookieClient`
    - `CookieHeaderCache`

## Provider-by-Provider Plan

### 1. Codex

#### Current state

- 已有 OAuth + CLI fallback
- 已修 `credits.balance` 类型兼容
- 已修 `chatgpt_base_url` 路径解析

#### Remaining gaps

- [ ] app-server / OAuth source label 进一步细化
- [ ] UI 中显示更明确的 debug cause
- [ ] real-world workspace / enterprise response 验证
- [ ] `Codex CLI` 版本检查对齐 `CodexBar`

#### Reference

- [CodexOAuthUsageFetcher.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Codex/CodexOAuth/CodexOAuthUsageFetcher.swift)
- [CodexStatusProbe.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Codex/CodexStatusProbe.swift)
- [UsageFetcher.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/UsageFetcher.swift)

#### Completion criteria

- 能稳定显示：
  - plan
  - primary / weekly window
  - credits
  - source label
- `Codex` 版本字段应展示真实 CLI 版本，而不是路径或“未检测到”
- 出错时能显示 provider-specific reason，而不是泛化“格式错误”

### 2. Claude

#### Current state

- 已有 OAuth path
- 已有 CLI PTY `/usage` + `/status`

#### Remaining gaps

- [ ] `Claude web extras`
- [ ] delegated refresh
- [ ] richer trust-prompt / rate-limit / auth diagnostics
- [ ] source mode 完整对齐 `auto / oauth / web / cli`
- [ ] `Claude CLI` 版本检查与路径来源展示

#### Reference

- [ClaudeUsageFetcher.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Claude/ClaudeUsageFetcher.swift)
- [ClaudeStatusProbe.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Claude/ClaudeStatusProbe.swift)
- [ClaudeCLISession.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Claude/ClaudeCLISession.swift)

#### Completion criteria

- 同时支持：
  - OAuth
  - CLI
  - Web extras
- 周窗口和 Opus/Sonnet 窗口都能显示
- `Claude` 版本字段应能区分：
  - CLI binary version
  - OAuth-only detected
- 登录/权限/速率限制失败时有可操作错误提示

### 3. Cursor

#### Current state

- 只有 manual cookie mode

#### Remaining gaps

- [ ] browser cookie auto import
- [ ] cookie source mode
- [ ] session validation
- [ ] login flow
- [ ] cached cookie metadata
- [ ] `Cursor CLI / app` 版本与运行时来源检测

#### Reference

- [CursorStatusProbe.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Cursor/CursorStatusProbe.swift)
- [CursorLoginRunner.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/CursorLoginRunner.swift)
- [CursorProviderImplementation.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/Providers/Cursor/CursorProviderImplementation.swift)

#### Completion criteria

- `auto / manual / off` cookie source 可切换
- 自动从浏览器拿到可用 session 时无需手填 cookie
- 可显示 `Total / Auto / API`
- 版本字段应至少能稳定显示可执行版本或 app 版本来源

### 4. Amp

#### Current state

- 只有 manual cookie mode

#### Remaining gaps

- [ ] browser cookie auto import
- [ ] redirect diagnostics
- [ ] debug raw probe
- [ ] cookie source mode
- [ ] `Amp CLI` 插件/脚本版本检测

#### Reference

- [AmpUsageFetcher.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Amp/AmpUsageFetcher.swift)
- [AmpProviderImplementation.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/Providers/Amp/AmpProviderImplementation.swift)

#### Completion criteria

- 自动导入浏览器 session 后可以直接刷新
- 出错时能看到 session / redirect / login 诊断
- 版本字段应能反映本地 `Amp CLI` / plugin runtime 版本

### 5. Augment

#### Current state

- 只有 manual cookie mode

#### Remaining gaps

- [ ] browser cookie auto import
- [ ] cookie-name fallback detection
- [ ] runtime keepalive / force refresh
- [ ] debug dump
- [ ] `Augment` 本地 runtime / app version 检测

#### Reference

- [AugmentStatusProbe.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Augment/AugmentStatusProbe.swift)
- [AugmentProviderRuntime.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBar/Providers/Augment/AugmentProviderRuntime.swift)

#### Completion criteria

- 自动 session 导入可用
- credits / subscription 可稳定合并
- 失效后可以快速重刷或重建 session
- 版本字段应稳定显示本地 runtime 版本或 app 来源

### 6. OpenCode

#### Current state

- manual cookie + workspace ID override

#### Remaining gaps

- [ ] browser cookie auto import
- [ ] workspace auto-detection 稳定性增强
- [ ] provider-specific debug probe
- [ ] richer usage source diagnostics
- [ ] `OpenCode` CLI / app 版本检测

#### Reference

- [OpenCodeUsageFetcher.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/OpenCode/OpenCodeUsageFetcher.swift)

#### Completion criteria

- 自动 cookie 可用
- billing workspace 能自动识别，必要时可 override
- 5h / weekly window 稳定显示
- 版本字段可显示 OpenCode 本地版本或来源

### 7. Gemini

#### Current state

- OAuth quota 已可用
- 多窗口 UI 已可显示

#### Remaining gaps

- [ ] provider-specific version/runtime detection更准确
- [ ] richer project/tier diagnostics
- [ ] more resilient bucket mapping

#### Reference

- `GeminiStatusProbe`
- `GeminiProviderImplementation`

#### Completion criteria

- `Pro / Flash / Flash Lite` 稳定显示
- 可清楚显示使用的是哪个 project/tier
- `Gemini CLI` 版本字段不再只是 binary path

### 8. Kiro

#### Current state

- CLI `/usage` 可用

#### Remaining gaps

- [ ] provider-specific version parse
- [ ] 更细粒度 CLI diagnostics
- [ ] output format resilience

#### Completion criteria

- CLI 失败时可明确区分：
  - 未登录
  - CLI 不存在
  - 输出结构变化
- `Kiro CLI` 版本字段应稳定显示真实版本

### 9. JetBrains AI

#### Current state

- local quota file 可用

#### Remaining gaps

- [ ] 多 IDE 检测策略继续增强
- [ ] richer refill/plan copy
- [ ] IDE / plugin version 检测文本统一

#### Completion criteria

- 主窗口 + refill 信息稳定显示
- 版本字段可解释当前数据来自哪个 IDE / 版本

### 10. Copilot

#### Current state

- GitHub token 模式可用

#### Remaining gaps

- [ ] richer account / plan / reset 信息
- [ ] more resilient internal API decoding
- [ ] `Copilot CLI / extension` 版本来源检测

#### Completion criteria

- Premium / Chat 两条窗口稳定显示
- 版本字段可标明当前实际使用的客户端来源

## Rollout Order

建议严格按这个顺序：

1. `Codex` 稳定性收尾
2. `Claude` 完整 source parity
3. `Cursor`
4. `Amp`
5. `Augment`
6. `OpenCode`
7. `Gemini`
8. `Kiro`
9. `JetBrains AI`
10. `Copilot`

原因：

- 前 6 项最直接影响“活跃数据可用”
- 后面几项更多是完善与稳固

## Acceptance Checklist

每完成一个 provider，都要同时满足：

- [ ] provider 可检测
- [ ] provider 的 CLI / app / IDE 版本可检测并正确展示
- [ ] provider source 在 UI 可见
- [ ] 至少一条 live-data 路径在真实账号下可用
- [ ] 最近错误文案明确
- [ ] 至少一条专属解析/兼容测试通过
- [ ] settings workspace 可完成配置与刷新闭环
