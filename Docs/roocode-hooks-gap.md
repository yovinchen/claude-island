# Roo Code — 差距分析

> 官方文档: https://docs.roocode.com/
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前无 Roo Code 接入 |
| README / docs | ❌ | 暂无 Roo Code 审计记录 |

## 官方可用扩展面

| 能力 | 状态 | 说明 |
|------|------|------|
| 独立 hooks 文档 | 未找到 | 官方公开文档首页未暴露 hooks 页面 |
| Custom Modes | ✅ | 官方强调可定制 modes |
| Checkpoints | ✅ | 官方提供 checkpoints / 回滚 |
| MCP | ✅ | 官方明确支持 MCP servers |
| Auto-Approve | ✅ | 官方强调扩展内置 auto-approve 与权限流 |

## 可替代实现方式

1. 通过 MCP、custom modes、checkpoints 对齐 Claude Island 的“规则/审计”诉求。
2. 若官方后续公布 hooks 或事件 API，再评估 installer 路线。

## 结论

Roo Code **当前不支持接入**。官方现阶段公开的是 mode / checkpoint / MCP 等能力，而不是可直接写入的 hooks 规范。
