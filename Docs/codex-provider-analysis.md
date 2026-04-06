# Codex Provider Analysis

## Symptom

当前 `Claude Island` 中 `Codex` provider 出现的最近错误是：

`未能读取数据，因为它的格式不正确。`

这类错误通常不是“没有登录”，而是：

1. OAuth usage API 返回了和当前解码模型不完全一致的 JSON
2. 请求 URL 命中了错误的 endpoint，返回了 HTML 或其它非目标 JSON
3. app-server / OAuth 两条路径都没有给出足够明确的错误描述

## Current Claude Island Logic

关键文件：

- [OAuthCLIQuotaProviders.swift](/Users/yovinchen/project/claude-island/ClaudeIsland/Quota/Providers/OAuthCLIQuotaProviders.swift)

现有路径：

1. 读取 `~/.codex/auth.json`
2. 如果能拿到 OAuth token，则请求：
   - `https://chatgpt.com/backend-api/wham/usage`
3. 若 OAuth 失败，则回退到 `codex app-server`
4. app-server 调用：
   - `account/read`
   - `account/rateLimits/read`

## Current Local Environment

从当前机器读取到：

- `~/.codex/auth.json` 存在
- `auth_mode = "chatgpt"`
- `tokens.access_token` / `refresh_token` / `account_id` 都存在
- `chatgpt_plan_type = "pro"`
- `~/.codex/config.toml` 存在，但当前没有设置 `chatgpt_base_url`

这说明：

- 问题不是因为 Codex 未登录
- 更可能是 usage API 返回内容与当前解码结构不完全一致

## Comparison With CodexBar

### 1. Credits balance decoding

`CodexBar` 在 [CodexOAuthUsageFetcher.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Codex/CodexOAuth/CodexOAuthUsageFetcher.swift) 中对 `credits.balance` 做了兼容：

- 先尝试 `Double`
- 再尝试 `String -> Double`

`Claude Island` 原本只接受 `Double`。

这会导致一种常见失败：

- 后端把 `balance` 返回为字符串，比如 `"12.34"`
- 当前 JSONDecoder 直接报解码错误
- UI 最终显示“数据格式不正确”

### 2. Usage URL resolution

`CodexBar` 不会写死 `https://chatgpt.com/backend-api/wham/usage`。
它会：

1. 读取 `~/.codex/config.toml`
2. 解析 `chatgpt_base_url`
3. 如果 base URL 包含 `/backend-api`，用 `/wham/usage`
4. 否则改走 `/api/codex/usage`

这段逻辑同样在：

- [CodexOAuthUsageFetcher.swift](/Users/yovinchen/project/CodexBar/Sources/CodexBarCore/Providers/Codex/CodexOAuth/CodexOAuthUsageFetcher.swift)

`Claude Island` 原本写死了 `/backend-api/wham/usage`。

这会导致一种常见失败：

- 本地 Codex 配置了自定义 `chatgpt_base_url`
- 请求命中了错误路径
- 返回 HTML / 错误 JSON
- 解码时报“格式不正确”

### 3. Error wrapping

`CodexBar` 会把 decode/network/server 失败包成更具体的 `CodexOAuthFetchError`。

`Claude Island` 原本让 `JSONDecoder().decode(...)` 的底层错误直接冒泡。

所以用户只能看到：

- “未能读取数据，因为它的格式不正确。”

而不是更有价值的：

- `Codex usage API returned unexpected JSON`
- 再附带 body snippet

## Root Cause Assessment

当前最可能的两个根因：

1. `credits.balance` 字段类型变化
2. usage URL 解析过于写死

其中第一个最容易直接触发当前中文错误文案。  
第二个则会在某些 Codex 配置下把错误放大成“返回内容不是预期 JSON”。

## Fixes Applied In Claude Island

本轮已做：

1. `credits.balance` 兼容 `Double / String`
2. 迁入 `chatgpt_base_url` 解析逻辑
3. 兼容 `/wham/usage` 与 `/api/codex/usage`
4. 对 decode 失败补充 body snippet 包装，避免只显示系统级“格式不正确”

实现位置：

- [OAuthCLIQuotaProviders.swift](/Users/yovinchen/project/claude-island/ClaudeIsland/Quota/Providers/OAuthCLIQuotaProviders.swift)

## Remaining Risks

即使上面的修复已经落地，仍可能存在：

- app-server 返回结构变化
- OAuth usage 响应新增字段嵌套
- 某些企业/工作区账号下 window 字段为空或结构不同

## Recommended Next Steps

1. 在 `Codex` provider UI 中补更明确的 debug text
2. 如果 `Codex` 仍失败，优先打印 usage API body snippet
3. 后续补 `Codex` 专项回归测试：
   - `credits.balance` 为 string
   - custom `chatgpt_base_url`
   - `/api/codex/usage` 路径选择
