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

## 建议补齐方向

1. 新增 `SessionSource.qoderCLI`，与现有 `qoder` 分开。
2. 针对 CLI 的配置路径、事件列表、stdout 响应格式单独实现安装器。
3. README 中把 `Qoder` 和 `Qoder CLI` 拆开标注，避免误判。

## 结论

Qoder CLI **当前不应视为已支持**。虽然仓库里已有 `Qoder` 集成，但那套实现更接近 IDE hooks，不足以覆盖官方 CLI hooks 能力。

## 基于本地代码的实现可行性

**可行性评级**: 高

**可直接复用**
- `QoderHookSource`、`PermissionHandler`、`HookSocketServer` 已经把 Qoder 的 `PreToolUse.permissionDecision` 路线打通了一半。
- 因为 `.qoder` 已在 UI、repair、displayName 体系里存在，新增 `qoder_cli` 更像 source 拆分，而不是从零开始。

**最小实现方案**
1. 新增 `SessionSource.qoderCLI`，不要继续把 CLI 和 IDE 共用一个 source。
2. 把现有 Qoder 的 stdout 审批逻辑复用到 CLI source。
3. 再按官方 CLI 事件表补 SessionStart/End、PermissionRequest、PreCompact 等差异项。

**主要阻塞**
- 阻塞点是“当前 Qoder 实现语义不够区分 CLI 与 IDE”，不是协议完全缺失。
