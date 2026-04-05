# Crush — 差距分析

> 官方仓库: https://github.com/charmbracelet/crush
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前无 Crush 接入 |
| README / docs | ❌ | 仓库暂无 Crush 兼容性记录 |

## 官方可用扩展面

| 能力 | 状态 | 说明 |
|------|------|------|
| 独立 hooks 文档 | 未发现 | 官方仓库 README 未暴露 lifecycle hooks |
| MCP | ✅ | README 明确支持 `stdio` / `http` / `sse` 三类 MCP transport |
| 权限控制 | ✅ | README 有权限与 tool access 说明 |
| 指令 / slash commands | ✅ | README 展示 commands、agents、skills 等可扩展面 |

## 可替代实现方式

1. 通过 MCP / slash command / skills 接近规则注入，而不是 hooks。
2. 若后续要做 Claude Island 兼容，更可能需要读取 Crush session/state 文件或包裹其 CLI。

## 结论

Crush **当前不支持接入**。公开资料显示它有 MCP、权限和命令扩展，但没有现成的本地 hooks 配置面可复用。
