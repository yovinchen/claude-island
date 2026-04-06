# Non-Codex Provider Qualification Analysis

## Goal

这份文档只看 `Codex` 以外的 provider，回答三个问题：

1. `CodexBar` 现在到底是怎么拿数据的
2. `Claude Island` 当前实现是否已经“合格”
3. 下一步应该先补哪一层，才能让额度、百分比、重置时间、账号信息完整展示

这里的“合格”定义为：

- 可以稳定拿到真实数据，而不是只有 UI 壳子
- 能显示至少一条真实额度窗口，最好能显示多窗口
- 能显示已用百分比
- 能显示重置时间或明确说明无重置时间
- 能显示账号 / 计划 / credits 等身份信息中的可用部分
- 能给出可操作的错误原因
- 对 CLI / 本地 runtime 型 provider，版本检测要能工作
- 对 cookie / session 型 provider，至少要有可复现的数据来源策略

## CodexBar Backend Shape

`CodexBar` 的后端不是“每个 provider 各写一个 fetch 请求”这么简单，而是一条完整管线：

### 1. 统一 fetch 入口

- `Sources/CodexBarCore/Providers/ProviderFetchPlan.swift`
- `Sources/CodexBarCore/UsageFetcher.swift`

关键点：

- 先决定 `sourceMode`
- 再决定 `strategy` 列表
- 再按顺序尝试 `cli / web / oauth / api / localProbe`
- 每次尝试都会记录 attempt，失败后决定是否 fallback

这就是为什么 `CodexBar` 能做到同一个 provider 有 `auto / web / cli / oauth / api` 多条路径，而不是把 source 写死在某个 view 里。

### 2. 后端逻辑如何找

如果后续要“直接把 CodexBar 后端逻辑参考过来”，查找顺序应该固定：

1. `Sources/CodexBar/Providers/<Provider>/<Provider>ProviderImplementation.swift`
   - 看设置页暴露了哪些 source、picker、field、toggle
2. `Sources/CodexBarCore/Providers/<Provider>/`
   - 看真正的 fetcher / probe / parser / cookie importer
3. `Sources/CodexBar/Providers/<Provider>/<Provider>ProviderRuntime.swift`
   - 看 session keepalive、失败恢复、自动重刷
4. `Sources/CodexBar/Providers/<Provider>/<Provider>LoginFlow.swift`
   - 看登录流程
5. `Sources/CodexBarCore/Providers/ProviderVersionDetector.swift`
   - 看 CLI / app 版本检测
6. `Sources/CodexBarCore/BrowserDetection.swift`
   - 看浏览器探测
7. `Sources/CodexBarCore/BrowserCookieImportOrder.swift`
   - 看 cookie 导入顺序
8. `Sources/CodexBarCore/CookieHeaderCache.swift`
   - 看 cookie 缓存与来源标签

### 3. UI 端是如何完整展示数据的

- `Sources/CodexBar/PreferencesProviderDetailView.swift`
- `Sources/CodexBar/UsageProgressBar.swift`

`CodexBar` 的 detail pane 不只显示一个 percent，它会同时展示：

- `State / Source / Version / Updated / Status / Account / Plan`
- 多条 metrics
- 每条 metric 的：
  - progress
  - percent label
  - reset text
  - left/right detail text
  - supplementary detail text
- credits 文本
- provider cost
- token usage
- usage notes

这点和 `Claude Island` 当前实现最本质的差异，不是“有没有进度条”，而是 `CodexBar` 的数据模型已经允许每个 provider 把更多结构化细节挂出来。

## Current Claude Island Shape

当前 `Claude Island` 已有这些基础能力：

- `ClaudeIsland/Quota/Core/QuotaStore.swift`
  - provider 级刷新、错误记录、排序、header risk
- `ClaudeIsland/Quota/Domain/QuotaModels.swift`
  - `primary / secondary / tertiary window`
  - `credits`
  - `identity`
- `ClaudeIsland/UI/Views/QuotaViews.swift`
  - 左侧 provider list
  - 右侧 detail workspace
  - `overview / usage / credits / note / error / configuration`

这意味着 UI 基础不是最大问题。最大问题是：

- source planner 还没有对齐 `CodexBar`
- cookie providers 大多仍是手填 cookie
- runtime keepalive / session recovery 基本没有
- debug probe 没成体系
- 一部分 provider 的版本检测仍然不够 provider-aware

## Qualification Matrix

### Claude

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Claude/ClaudeUsageFetcher.swift`
- `Sources/CodexBarCore/Providers/Claude/ClaudeStatusProbe.swift`
- `Sources/CodexBarCore/Providers/Claude/ClaudeCLISession.swift`
- `Sources/CodexBarCore/Providers/Claude/ClaudeWeb/ClaudeWebAPIFetcher.swift`
- `Sources/CodexBar/Providers/Claude/ClaudeProviderImplementation.swift`

`CodexBar` 已有能力：

- OAuth fetch
- CLI PTY `/usage`
- web API extras
- `usage source` + `cookie source` 双层设置
- cookie source `auto / manual / off`
- login / delegated refresh / richer auth diagnostics

`Claude Island` 当前状态：

- 已有 OAuth fetch
- 已有 CLI `/usage` + `/status`
- 版本检测已做 provider-specific 清洗
- 还没有 web extras
- 还没有完整的 source planner
- 还没有 cookie source state machine

判定：

- `部分合格`

主要缺口：

- web data lane 缺失
- `auto / oauth / cli / web` 没有统一策略层
- trust/auth/rate-limit 错误不够细

### Gemini

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Gemini/GeminiProviderDescriptor.swift`
- `Sources/CodexBarCore/Providers/Gemini/GeminiStatusProbe.swift`
- `Sources/CodexBar/Providers/Gemini/GeminiProviderImplementation.swift`

`CodexBar` 已有能力：

- OAuth usage
- CLI/version detection
- status probe
- login flow

`Claude Island` 当前状态：

- 已有 OAuth quota fetch
- 已有 provider-aware CLI version detection
- 没有 status probe parity
- 没有更完整 debug cause

判定：

- `部分合格`

主要缺口：

- 状态探针
- 更细的失败诊断
- 与 `CodexBar` 一样的 source/planner 结构

### Kiro

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Kiro/KiroStatusProbe.swift`
- `Sources/CodexBarCore/Providers/Kiro/KiroProviderDescriptor.swift`
- `Sources/CodexBar/Providers/Kiro/KiroProviderImplementation.swift`

`CodexBar` 已有能力：

- CLI `/usage`
- status probe
- provider-specific version detection

`Claude Island` 当前状态：

- 已有 CLI fetch
- 已有 CLI version detection
- 没有 status probe parity

判定：

- `部分合格`

主要缺口：

- 服务状态探针
- 更丰富的 credits/bonus 诊断信息

### Copilot

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Copilot/CopilotUsageFetcher.swift`
- `Sources/CodexBarCore/Providers/Copilot/CopilotDeviceFlow.swift`
- `Sources/CodexBar/Providers/Copilot/CopilotProviderImplementation.swift`
- `Sources/CodexBar/Providers/Copilot/CopilotLoginFlow.swift`

`CodexBar` 已有能力：

- device flow 登录
- token store
- usage fetch
- UI 上能展示 premium/chat 两类额度

`Claude Island` 当前状态：

- 已有 token 驱动的 API fetch
- 能显示 primary/secondary windows
- 没有 device flow 登录
- 没有完整 token account / login runner

判定：

- `部分合格`

主要缺口：

- 登录流程
- token 生命周期
- 更强的 UI 文案与错误指导

### Cursor

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Cursor/CursorStatusProbe.swift`
- `Sources/CodexBar/Sources/CodexBar/CursorLoginRunner.swift`
- `Sources/CodexBar/Providers/Cursor/CursorProviderImplementation.swift`
- `Sources/CodexBar/Providers/Cursor/CursorSettingsStore.swift`

`CodexBar` 已有能力：

- 浏览器 cookie 自动导入
- 登录 runner
- cookie source `auto / manual / off`
- session validation
- `Total / Auto / API`
- on-demand usage note
- cookie cache source label

`Claude Island` 当前状态：

- 已有 manual cookie fetch
- 已能显示 `Total / Auto / API`
- 已有 Cursor app version fallback
- 没有 browser cookie auto import
- 没有 login runner
- 没有 cookie source state machine
- 没有 cached cookie metadata

判定：

- `不合格`

为什么当前不合格：

- UI 虽然有数据位，但数据来源仍主要依赖手填 cookie
- 不具备 `CodexBar` 那种“装上就能直接抓”的能力

### OpenCode

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/OpenCode/OpenCodeUsageFetcher.swift`
- `Sources/CodexBarCore/Providers/OpenCode/OpenCodeCookieImporter.swift`
- `Sources/CodexBar/Providers/OpenCode/OpenCodeProviderImplementation.swift`
- `Sources/CodexBar/Providers/OpenCode/OpenCodeSettingsStore.swift`

`CodexBar` 已有能力：

- browser cookie import
- workspace 自动发现
- workspace override
- GET / POST fallback
- parse fallback
- richer parse diagnostics

`Claude Island` 当前状态：

- 已有 manual cookie fetch
- 已有 workspace ID override
- 已有 workspace 自动抓取
- 已有 GET / POST fallback
- 版本检测已能回退到包版本
- 没有 browser cookie auto import
- 没有 cached source metadata

判定：

- `部分合格`

原因：

- 真实抓数逻辑已经不只是壳子
- 但缺少 `CodexBar` 最关键的自动 session 导入体验

### Amp

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Amp/AmpUsageFetcher.swift`
- `Sources/CodexBarCore/Providers/Amp/AmpUsageParser.swift`
- `Sources/CodexBar/Providers/Amp/AmpProviderImplementation.swift`

`CodexBar` 已有能力：

- browser cookie import
- redirect diagnostics
- debug raw probe
- HTML parse + debug hint
- cookie source `auto / manual / off`

`Claude Island` 当前状态：

- 已有 manual cookie fetch
- 已有 HTML parse
- 已能显示 quota used/total 和估算 reset
- 还没有 browser cookie auto import
- 还没有 debug raw probe surface
- 还没有 redirect/session 诊断视图
- 版本检测还没有真正挂到 Amp 行上

判定：

- `不合格`

### Augment

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Augment/AugmentStatusProbe.swift`
- `Sources/CodexBarCore/Providers/Augment/AugmentSessionKeepalive.swift`
- `Sources/CodexBar/Providers/Augment/AugmentProviderRuntime.swift`
- `Sources/CodexBar/Providers/Augment/AugmentProviderImplementation.swift`

`CodexBar` 已有能力：

- browser cookie import
- session keepalive
- session expired recovery
- runtime-triggered refresh
- credits + subscription merge

`Claude Island` 当前状态：

- 已有 manual cookie fetch
- 已能显示 credits / used / total / reset
- 没有 browser cookie auto import
- 没有 runtime keepalive
- 没有 session expired recovery
- 没有 provider runtime

判定：

- `不合格`

### Kimi

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Kimi/KimiUsageFetcher.swift`
- `Sources/CodexBarCore/Providers/Kimi/KimiCookieImporter.swift`
- `Sources/CodexBar/Providers/Kimi/KimiProviderImplementation.swift`

`CodexBar` 已有能力：

- browser cookie import
- manual cookie / token fallback
- coding scope usage fetch
- weekly + short-window 双额度

`Claude Island` 当前状态：

- 已有 auth token fetch
- 已能显示 weekly + short window
- 没有 browser cookie import
- 没有 cookie source mode

判定：

- `部分合格`

### JetBrains AI

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/JetBrains/JetBrainsIDEDetector.swift`
- `Sources/CodexBarCore/Providers/JetBrains/JetBrainsStatusProbe.swift`
- `Sources/CodexBar/Providers/JetBrains/JetBrainsProviderImplementation.swift`

`CodexBar` 已有能力：

- IDE detection
- quota file detection
- login guidance
- local quota parse

`Claude Island` 当前状态：

- 已有 local quota fetch
- 已能显示 IDE identity
- 缺少更完整的引导文案与状态诊断

判定：

- `基本合格`

### OpenRouter

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/OpenRouter/OpenRouterSettingsReader.swift`
- `Sources/CodexBar/Providers/OpenRouter/OpenRouterProviderImplementation.swift`

`CodexBar` 已有能力：

- API key
- credits/balance
- key limit / usage

`Claude Island` 当前状态：

- 已有 credits fetch
- 已有 key usage fetch
- 已能显示 credits、balance、limit usage

判定：

- `基本合格`

### Warp

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Warp/WarpUsageFetcher.swift`
- `Sources/CodexBarCore/Providers/Warp/WarpSettingsReader.swift`
- `Sources/CodexBar/Providers/Warp/WarpProviderImplementation.swift`

`CodexBar` 已有能力：

- GraphQL request limit info
- bonus grants
- reset time
- app/API key settings

`Claude Island` 当前状态：

- 已有 GraphQL fetch
- 已能显示 primary credits + add-on grants
- 版本检测还没挂 Warp app version

判定：

- `基本合格`

### Kimi K2

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/KimiK2/KimiK2UsageFetcher.swift`
- `Sources/CodexBar/Providers/KimiK2/KimiK2ProviderImplementation.swift`

`CodexBar` 已有能力：

- API key quota / credits

`Claude Island` 当前状态：

- 已有 API key fetch
- 已能显示 credits

判定：

- `基本合格`

### z.ai

`CodexBar` 参考：

- `Sources/CodexBarCore/Providers/Zai/ZaiSettingsReader.swift`
- `Sources/CodexBarCore/Providers/Zai/ZaiUsageStats.swift`
- `Sources/CodexBar/Providers/Zai/ZaiProviderImplementation.swift`

`CodexBar` 已有能力：

- API key
- region setting
- token / subscription usage

`Claude Island` 当前状态：

- 已有 API key fetch
- 已有 region picker
- 已能显示 tokens / MCP 或 credits 信息

判定：

- `基本合格`

## Summary Table

| Provider | Current verdict | Biggest missing piece |
| --- | --- | --- |
| Claude | 部分合格 | web extras + unified source planner |
| Gemini | 部分合格 | status/debug parity |
| Kiro | 部分合格 | status/debug parity |
| Copilot | 部分合格 | device flow login |
| Cursor | 不合格 | browser cookie auto import + login/runtime |
| OpenCode | 部分合格 | browser cookie auto import |
| Amp | 不合格 | browser cookie auto import + debug/redirect diagnostics |
| Augment | 不合格 | auto cookie + keepalive/runtime recovery |
| Kimi | 部分合格 | cookie import + source mode |
| JetBrains AI | 基本合格 | richer diagnostics |
| OpenRouter | 基本合格 | polish only |
| Warp | 基本合格 | app/runtime version surfacing |
| Kimi K2 | 基本合格 | polish only |
| z.ai | 基本合格 | polish only |

## Priority Order

如果目标是“挂上数据后能完整展示”，优先级不应该再按 provider 名字排，而应该按缺的基础设施排：

### Priority 1: Cookie/session foundation

先补这些共享层：

- browser detection
- cookie import order
- cookie cache metadata
- `auto / manual / off`
- session validation helper

会直接提升：

- Cursor
- OpenCode
- Amp
- Augment
- Kimi

### Priority 2: Provider runtime and recovery

先补这些：

- provider runtime abstraction
- session expired recovery
- keepalive / force refresh
- richer provider diagnostics

会直接提升：

- Augment
- Claude
- Cursor
- Amp

### Priority 3: Version/detection polish

需要补齐：

- Amp local runtime version
- Warp app version
- provider source label provenance
- override path vs PATH source

### Priority 4: UI detail parity

当前 `Claude Island` UI 已经有基本承载能力，但仍缺三点：

1. provider-specific usage notes 还不够结构化
2. debug probe 结果没有独立展示区
3. source/cache provenance 还没显示到 detail pane

## What Can Be Copied First

如果下一步要直接从 `CodexBar` 参考实现，最值得先搬的不是某个单一 provider，而是这些文件思路：

- `Sources/CodexBarCore/Providers/ProviderFetchPlan.swift`
- `Sources/CodexBarCore/Providers/ProviderVersionDetector.swift`
- `Sources/CodexBarCore/BrowserDetection.swift`
- `Sources/CodexBarCore/BrowserCookieImportOrder.swift`
- `Sources/CodexBarCore/CookieHeaderCache.swift`

然后按 provider 复制思路：

1. `Cursor`
   - `CursorStatusProbe.swift`
   - `CursorLoginRunner.swift`
2. `Amp`
   - `AmpUsageFetcher.swift`
   - `AmpUsageParser.swift`
3. `Augment`
   - `AugmentStatusProbe.swift`
   - `AugmentSessionKeepalive.swift`
   - `AugmentProviderRuntime.swift`
4. `OpenCode`
   - `OpenCodeCookieImporter.swift`
   - `OpenCodeUsageFetcher.swift`

## Direct Conclusion

如果不算 `Codex`，当前 `Claude Island` 里真正已经比较接近“可上线”的是：

- `JetBrains AI`
- `OpenRouter`
- `Warp`
- `Kimi K2`
- `z.ai`

已经有真实 fetch 但还没到 `CodexBar` 等级的是：

- `Claude`
- `Gemini`
- `Kiro`
- `Copilot`
- `OpenCode`
- `Kimi`

目前最不合格、也是最值得继续补的，是：

- `Cursor`
- `Amp`
- `Augment`

原因非常明确：它们现在不是“数据模型不够”，而是最关键的自动 session 获取、恢复和验证链路还没补上。
