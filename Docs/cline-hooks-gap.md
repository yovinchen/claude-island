# Cline / Cline CLI Hooks — 差距分析

> 官方文档: https://docs.cline.bot/features/hooks/hook-reference
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前没有 Cline / Cline CLI 接入源 |
| README / docs | ❌ | 仓库尚无 Cline 兼容性文档 |
| IDE 宿主识别 | 间接 | 若运行在 VS Code / Cursor / JetBrains，可借助现有宿主窗口聚焦逻辑，但不是 Cline 接入 |

## 官方可用扩展面

| 能力 | 状态 | 说明 |
|------|------|------|
| Hooks | ✅ | 官方文档列出 hook 参考与事件类型 |
| 规则系统 | ✅ | 官方文档强调 hooks 与 rules 配合使用 |
| Checkpoints | ✅ | 官方提供 checkpoint / rollback 配套能力 |
| Auto-Approve | ✅ | hooks 可与 Auto-Approve 共同工作 |

## 对 Claude Island 的主要 gap

1. 没有 `cline` source、配置目录、图标和安装检测。
2. 未接入 Cline 的 hook 事件与 stdout 响应格式。
3. 需要先确认 Cline CLI 与 VS Code 扩展是否共用同一 hooks schema；在未确认前，建议先合并成一份 gap 文档而不是拆成两套实现。

## 实现建议

1. 先做只读接入，覆盖会话开始、prompt 提交、工具前后、停止。
2. 再评估 `permissionDecision` / `Auto-Approve` 是否能安全接到 Notch 审批。
3. 若 Cline CLI 和扩展最终证实 schema 不同，再拆成 `cline` / `cline_cli` 两个 source。

## 结论

Cline / Cline CLI **官方 hooks 已存在，但 Claude Island 当前未接入**。这是明确的功能缺口。
