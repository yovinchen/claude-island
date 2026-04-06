# Qoder CLI Hooks — 差距分析

> CLI Hooks 文档: https://docs.qoder.com/ja/cli/hooks
> CLI 配置: https://docs.qoder.com/ja/using-qoder-cli/settings
> CLI 总览（含当前 Notification-only 说明）: https://docs.qoder.com/ja/cli/using-cli
> IDE Hooks 文档: https://docs.qoder.com/ja/extensions/hooks
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `qoder` source | ✅ | 仓库已支持 Qoder hooks，但实现更接近 IDE / extension 路线 |
| `qoder_cli` 独立 source | ❌ | 当前没有 CLI 与 IDE 的 source 拆分 |
| CLI 配置写入 | ❌ | 未写入 Qoder CLI 专属配置路径 |

## 官方可用扩展面

| 能力 | CLI | IDE / JetBrains 插件 | 说明 |
|------|-----|----------------------|------|
| Hooks | ✅ | ✅ | 官方分别提供 CLI hooks 与扩展 hooks 文档 |
| 事件模型 | 更完整 | 较精简 | CLI 文档列出 SessionStart/End、PermissionRequest、Subagent*、PreCompact 等 |
| 阻塞语义 | ✅ | ✅ | `exit 2` 可阻止特定事件 |
| 输出协议 | ✅ | ✅ | JSON stdout + `hookSpecificOutput` |

## 官方资料冲突

当前官方资料存在一个需要谨慎对待的分叉：

1. [`cli/hooks`](https://docs.qoder.com/ja/cli/hooks) 页面给出了完整 CLI hooks 矩阵，包含 `SessionStart / SessionEnd / PreToolUse / PermissionRequest / Subagent* / PreCompact / Notification` 等。
2. [`cli/using-cli`](https://docs.qoder.com/ja/cli/using-cli) 页面则明确写着：**“当前 Qoder CLI 支持的只有 Notification hooks，更多 hook 类型仍在计划中。”**

这意味着：

- CLI hooks 能力很可能还在快速演进；
- 仅凭其中一页文档，不足以支持当前仓库立即拆出一个稳定的 `qoder_cli` source。

## 现状判断

1. 当前仓库的 [Qoder 文档](./qoder-hooks-gap.md) 与 `QoderHookSource` 只覆盖了 5 个事件，更像 IDE / extension 版本。
2. 官方 `cli/hooks` 文档显示 Qoder CLI 的 hooks 能力比当前实现更多，但 `using-cli` 又把 CLI 描述成 Notification-only。
3. 这意味着 “Qoder 已支持” 只对 IDE hooks 近似成立，**对 `qodercli` 仍然不能算已支持**，同时也不适合在当前阶段贸然拆 source。

## 当前决策

1. 当前 **不拆** `SessionSource.qoderCLI`。
2. README 继续把 `Qoder CLI` 单独列为未接入对象，用于表达能力边界，而不是代码层已有独立 source。
3. 只有在后续确认 CLI 与 IDE 存在稳定且不同的配置入口时，才重新评估 source 拆分。

## 结论

Qoder CLI **当前不应视为已支持**。虽然仓库里已有 `Qoder` 集成，但那套实现更接近 IDE hooks，不足以覆盖官方 CLI hooks 能力。

## 基于本地代码的实现可行性

**可行性评级**: 高

**可直接复用**
- `QoderHookSource`、`PermissionHandler`、`HookSocketServer` 已经把 Qoder 的 `PreToolUse.permissionDecision` 路线打通了一半。
- 因为 `.qoder` 已在 UI、repair、displayName 体系里存在，新增 `qoder_cli` 更像 source 拆分，而不是从零开始。

**最小实现方案**
1. 继续保留现有 `qoder` source 代表 IDE / extension 路线。
2. 若后续证实 CLI 配置入口稳定，再从当前 `qoder` 审批逻辑抽一层出来复用。
3. 在真正拆分前，不把未落地的 `qoder_cli` 放进代码枚举和 UI。

**主要阻塞**
- 当前阻塞点已经明确变成两件事：
  1. CLI hooks 能力本身是否已经稳定，不再与 Notification-only 文档冲突；
  2. 配置入口是否足够稳定到值得拆 source。
