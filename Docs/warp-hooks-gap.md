# Warp Agents / Integrations — 差距分析

> 官方文档: https://docs.warp.dev/agent-platform/getting-started/agents-in-warp
> 官方集成: https://docs.warp.dev/agent-platform/integrations/integrations-overview
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前代码没有 `warp` 接入源，也没有配置写入器 |
| 宿主终端识别 | ✅ | `TerminalAppRegistry` 已识别 `Warp` 名称和 `dev.warp.Warp-Stable` bundle id |
| Hook/审批链路 | ❌ | 无 `HookInstaller`、`EventMapper`、`HookSocketServer` 适配 |

## 官方可用扩展面

| 能力 | 官方状态 | 说明 |
|------|------|------|
| 本地生命周期 hooks | 未见官方文档 | Warp 当前公开文档主打 Oz agents 与 cloud integrations，未提供 Claude/Cursor 风格本地 hook schema |
| Cloud Agents | ✅ | Warp/Oz agent 可在本地终端或云端环境中运行 |
| Slack / Linear 集成 | ✅ | 可通过 Warp/Oz integration 从 Slack、Linear 触发 agent |
| GitHub 写回 | ✅ | 官方文档要求授权 Warp GitHub app 以创建 PR、写回仓库 |
| Live session sharing | ✅ | 官方文档支持在 Warp 或浏览器中观察远程 agent 会话 |

## 可替代实现方式

1. 如果目标只是“识别正在使用 Warp 作为宿主终端”，当前仓库已经部分具备能力，无需新增 Hook 接入。
2. 如果目标是“追踪 Warp agent 生命周期”，更现实的路线是接 Oz/Warp CLI 或远端 session/log API，而不是等待本地 hook。
3. 如果目标是“从 Slack / Linear 触发后回传到 Claude Island”，需要新增独立的 Warp cloud-agent 适配层，而不是复用现有 Unix socket hook 模型。

## 对 Claude Island 的主要 gap

1. 缺少 `warp` source、图标、配置路径与安装检测。
2. 缺少可消费的本地 hook 协议，无法复用现有 `HookInstaller` 体系。
3. 若走 Oz/cloud agent 路线，需要新增远程任务状态同步、会话链接、PR 回传等全新数据模型。

## 结论

Warp **当前不属于已支持接入对象**。它在本仓库里仅作为“终端宿主”被识别，而不是可安装 hooks 的 AI 工具。官方当前更接近 “Warp/Oz cloud integrations + session sharing”，不是本地 hook-first 产品。

## 基于本地代码的实现可行性

**可行性评级**: 低（直连 hooks） / 中（远端会话旁路）

**可直接复用**
- `TerminalAppRegistry`、`SessionState.terminalAppName`、`TerminalFocuser` 已能把 Warp 当成宿主终端识别。

**可实施方案**
1. 最小可做的是继续强化 Warp 作为宿主终端的识别与聚焦，不新增 `SessionSource`。
2. 若要追踪 Warp agent，会变成 watcher / API 集成项目，需要新增独立同步层，而不是改 `HookInstaller`。

**主要阻塞**
- 当前仓库的核心骨架是“本地配置写入 + stdin/stdout hook + Unix socket”，Warp 公共资料并不提供这个面。
