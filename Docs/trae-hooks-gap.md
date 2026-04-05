# Trae IDE / Agent — 差距分析

> 官方文档入口: https://www.trae.ai/
> 公开资料: https://traeide.com/news/6
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource.trae` | ⚠️ | 已有枚举、图标与 README 占位 |
| `HookInstaller` 接入 | ❌ | `HookInstaller.allSources` 未启用 `TraeHookSource` |
| 官方支持标记 | ❌ | `HookInstaller.unsupportedSources` 明确将 `.trae` 视为不支持 |
| 独立 gap 文档 | ❌ | 当前仓库尚无 `docs/trae-hooks-gap.md` |

## 官方可用扩展面

| 能力 | 官方状态 | 说明 |
|------|------|------|
| JSON hooks | 未见公开文档 | 当前未找到稳定的官方 hooks API 文档 |
| `.rules` 行为约束 | ✅ | 公开资料明确提到 `.rules` 配置机制 |
| MCP | ✅ | 公开资料明确提到 MCP 支持 |
| 自定义 Agent / Prompt Toolset | ✅/有限 | 公开资料提到可配置 Agent prompt / toolset，但语法文档不稳定 |

## 可替代实现方式

1. 以 `.rules` 作为“静态规则注入”替代 hooks，适合做项目级约束。
2. 以 MCP 作为工具扩展面，替代部分 `PreToolUse` / `PostToolUse` 场景。
3. 若后续官方开放会话日志或 event stream，可新增 watcher 路线而非 installer 路线。

## 对 Claude Island 的主要 gap

1. 缺少官方、稳定、可写入的 hook 配置格式。
2. README 里虽然已有 “Trae 暂不支持” 描述，但没有独立的 gap 文档留痕。
3. 若未来支持，需要重新评估 `.rules`、MCP、Agent YAML/JSON 是否能映射到统一 `HookEvent`。

## 结论

Trae **当前不支持接入**。本仓库已为它保留 source 占位，但官方公开扩展面仍以 `.rules` 和 MCP 为主，尚不足以接入现有 hooks 管线。

## 基于本地代码的实现可行性

**可行性评级**: 低（installer） / 中（watcher）

**可直接复用**
- `SessionSource.trae`、显示名和图标占位已经存在，因此如果未来有稳定输入面，UI 接入成本较低。

**可实施方案**
1. 最小实现不是启用 `TraeHookSource`，而是先确认 Trae 是否存在稳定配置或日志目录，再决定 watcher 还是规则注入。
2. 如果未来有 JSON hooks，再补 `HookInstaller.allSources`、安装检测、UI 列表即可。

**主要阻塞**
- 目前连 `HookSource` 的输入假设都不成立，直接启用 `TraeHookSource` 只会制造伪支持。
