# Kimi Code CLI Hooks — 差距分析

> Hooks (Beta): https://moonshotai.github.io/kimi-cli/zh/customization/hooks.html
> 配置文件: https://moonshotai.github.io/kimi-cli/en/configuration/config-files.html
> IDE / ACP: https://moonshotai.github.io/kimi-cli/en/guides/ides.html
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前没有 Kimi CLI 接入源 |
| 安装检测 | ❌ | 仓库未检查 `~/.kimi/config.toml` 或 `kimi` 命令 |
| Hook / ACP 适配 | ❌ | 未支持 hooks，也未支持 `kimi acp` |

## 官方已提供的 Hook 能力

| 能力 | 状态 | 说明 |
|------|------|------|
| 生命周期 hooks | ✅ Beta | 官方文档列出 13 个事件 |
| 配置文件 | ✅ | `~/.kimi/config.toml` 中用 `[[hooks]]` 定义 |
| stdin JSON / exit code | ✅ | stdin 传上下文，exit `2` 可阻止操作 |
| 结构化输出 | ✅ | 支持 `hookSpecificOutput.permissionDecision` |
| ACP | ✅ | `kimi acp` 可供 JetBrains / Zed 等 IDE 接入 |

## 与现有仓库的差距

1. Kimi CLI 的 hook 模型和现有 `GenericSettingsHookSource` 很接近，但配置是 TOML 数组，不是 JSON `hooks` 对象。
2. 仓库目前既没做 hooks，也没做 ACP，因此在 Kimi 上是完全空白。
3. Kimi 还提供 `kimi acp`，后续存在“hooks 路线”和“ACP 路线”两种实现分支。

## 实现建议

1. 先做 hooks：因为 `PreToolUse` / `PostToolUse` / `Stop` / `SessionStart` 等事件已经足够覆盖 Claude Island 的核心 UI。
2. 再评估 ACP：更适合未来做 IDE 端嵌入或多会话管理。
3. README 中标记为“官方 hooks 已存在，当前未接入”。

## 结论

Kimi CLI **官方 hooks 已经具备，且还有 ACP 作为替代实现**；Claude Island 当前未接入，是一个明确的功能缺口。

## 基于本地代码的实现可行性

**可行性评级**: 高（hooks） / 中（ACP）

**可直接复用**
- `CodexHookSource` 已经证明本仓库能处理“CLI hooks + TOML/额外配置文件”路线。
- `HookSocketServer` 里现成有多套返回协议分支，可以继续扩展 Kimi 的 stdout 响应格式。

**最小实现方案**
1. 先复用 Codex 的 TOML 操作模式，实现 `KimiHookSource`。
2. 把 Kimi 事件映射进 `EventMapper`，优先覆盖 `SessionStart` / `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `Stop`。
3. ACP 单独作为第二阶段，不要和 hooks 首次接入耦合。

**主要阻塞**
- 主要是配置格式和事件名对齐，不是架构阻塞；这是当前最容易落地的新 CLI 之一。
