# JetBrains IDE Host / ACP — 差距分析

> JetBrains Air / Supported agents: https://www.jetbrains.com/help/air/supported-agents.html
> Kimi 在 JetBrains 中通过 ACP 接入: https://moonshotai.github.io/kimi-cli/en/guides/ides.html
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| JetBrains 窗口聚焦 | ✅ | `SessionState` / `TerminalFocuser` 已识别 IntelliJ、PyCharm、WebStorm、GoLand 等 bundle id |
| JetBrains hooks 接入 | ❌ | 当前没有 JetBrains 专属 `HookSource` |
| JetBrains 作为 ACP 宿主 | ❌ | 当前未利用 JetBrains AI Chat / Air 的 ACP 能力 |

## 官方可用扩展面

| 能力 | 状态 | 说明 |
|------|------|------|
| 原生 hooks | 未见统一官方文档 | JetBrains 更像是 agent host，而不是统一 hooks provider |
| ACP agents | ✅ | JetBrains Air / AI Chat 支持 Claude Agent、Codex、Gemini CLI、Junie 等 agent |
| 外部 CLI 接入 | ✅ | 官方 / 厂商文档显示可通过 ACP 将外部 CLI 挂到 JetBrains |

## 可替代实现方式

1. 走 ACP：把支持 ACP 的 CLI 接入 JetBrains，而不是直接对 JetBrains 做 hooks。
2. 走插件路线：分别适配在 JetBrains 里运行的具体 agent/plugin，例如 Kimi、Qoder、Copilot。
3. 保持现状：仅把 JetBrains 当成窗口聚焦宿主，不承担会话事件源角色。

## 结论

JetBrains **当前不是已支持的 hooks 接入对象**，但已经被本仓库当作“可聚焦的 IDE 宿主”部分支持。若后续要做深度集成，优先级应放在 ACP，而不是假设 JetBrains 自身提供统一 hooks。

## 基于本地代码的实现可行性

**可行性评级**: 低（直接 hooks） / 中高（ACP 宿主）

**可直接复用**
- `SessionState`、`TerminalFocuser`、`TerminalAppRegistry` 已经覆盖多数 JetBrains bundle id，宿主定位已经存在。

**可实施方案**
1. 把 JetBrains 继续当宿主，不新增 `jetbrains` source。
2. 如果未来要深度集成，优先接 ACP agent，把事件源落在底层 CLI，而不是 JetBrains 自身。

**主要阻塞**
- JetBrains 不是统一的事件提供者；没有稳定 hooks 面，就不应该强行抽象成独立 source。
