# Qoder CLI Hooks — 差距分析

> CLI Hooks 文档: https://docs.qoder.com/ja/cli/hooks
> CLI 配置: https://docs.qoder.com/ja/using-qoder-cli/settings
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

## 现状判断

1. 当前仓库的 [Qoder 文档](./qoder-hooks-gap.md) 与 `QoderHookSource` 只覆盖了 5 个事件，更像 IDE / extension 版本。
2. 官方 `cli/hooks` 文档显示 Qoder CLI 的 hooks 能力比当前实现更多。
3. 这意味着 “Qoder 已支持” 只对 IDE hooks 近似成立，**对 `qodercli` 仍然不能算已支持**。

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
- 当前阻塞点是“配置入口是否足够稳定到值得拆 source”，而不是协议完全缺失。
