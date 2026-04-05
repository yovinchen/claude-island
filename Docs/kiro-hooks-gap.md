# Kiro IDE / CLI Hooks — 差距分析

> IDE Hooks: https://kiro.dev/docs/hooks/types/
> CLI Hooks: https://kiro.dev/docs/cli/hooks/
> CLI 配置: https://kiro.dev/docs/cli/chat/configuration/
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前没有 Kiro 接入源 |
| 安装检测 / UI | ❌ | README、Onboarding、Settings 都没有 Kiro |
| Hook/审批链路 | ❌ | 无配置写入、无事件映射、无响应适配 |

## 官方可用扩展面

| 能力 | IDE | CLI | 说明 |
|------|-----|-----|------|
| Hooks | ✅ | ✅ | 两端都有官方 hooks 文档 |
| Tool hooks | ✅ | ✅ | IDE 有 Pre/Post Tool；CLI 有 Pre/Post Tool |
| Prompt hook | ✅ | ✅ | IDE `Prompt Submit`；CLI `UserPromptSubmit` |
| Stop/turn-end | ✅ | ✅ | IDE `Agent Stop`；CLI `Stop` |
| 文件事件 | ✅ | ❌ | IDE 额外支持 File Create / Save / Delete |
| ACP / 自定义 agents | — | ✅ | CLI 文档公开了 agent 配置目录 |

## 与现有仓库的差距

1. Kiro 是少数同时拥有 IDE hooks 和 CLI hooks 的目标，但仓库当前完全未接入。
2. 需要决定优先支持 IDE 还是 CLI，因为二者事件模型不完全相同。
3. IDE hooks 还支持 shell command 与 agent prompt 两种 action，需要明确只支持 shell-command 子集还是完整能力。

## 实现建议

1. 先做 `kiro-cli` 路线，原因是 JSON + stdin/stdout + exit code 更贴近现有架构。
2. 后续再评估 Kiro IDE hooks 是否值得单独建 `kiro_ide` source，还是合并成统一 `kiro`。
3. README 中把 Kiro 标为“官方有 hooks，当前未接入”。

## 结论

Kiro **官方 hooks 能力很强，但 Claude Island 当前完全未接入**。从实现难度看，它是非常适合补进路线图的一类目标。

## 基于本地代码的实现可行性

**可行性评级**: 中高

**可直接复用**
- CLI 路线可复用 `CodexHookSource` / `CursorHookSource` 的“独立安装器 + 自定义事件表”模式。
- 统一消费端可直接复用 `EventMapper`、`HookSocketServer`、UI source 列表。

**最小实现方案**
1. 先做 Kiro CLI，避免同时处理 IDE 与 CLI 两套 schema。
2. 新增自定义 `KiroHookSource`，不要强行塞进 `GenericSettingsHookSource`，直到事件名和配置结构完全确认。
3. 审批若存在标准 stdout/exit code，再复用 `PermissionHandler` 的隐式审批分支。

**主要阻塞**
- Kiro 现在最大的问题不是能不能接，而是先选 CLI 还是 IDE；两条线一起上会把 source 设计搞乱。
