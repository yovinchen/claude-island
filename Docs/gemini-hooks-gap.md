# Gemini CLI Hooks — 差距分析

> 官方文档: https://geminicli.com/docs/hooks/
> 设计分析: ./gemini-hooks-design.md
> 分析日期: 2026-04-06

## 当前仓库状态

| 功能 | 状态 | 说明 |
|------|------|------|
| `GeminiHookSource` | ✅ | 已支持写入 Gemini hooks 配置 |
| 事件归一化 | ✅ | `BeforeAgent` / `BeforeTool` / `AfterTool` / `AfterAgent` 等已映射 |
| `PermissionRequest` | ❌ | 官方本身无独立 PermissionRequest |
| 项目级配置诊断 | ⚠️ | 设计文档已指出项目级 `.gemini/settings.json` 仍可能覆盖用户级配置 |

## 已知剩余 gap

1. 仍需持续核对 Gemini 原生事件名，避免把 Claude 风格事件写回 Gemini 配置。
2. 尚未覆盖 `BeforeModel` / `AfterModel` / `BeforeToolSelection` 这类 Gemini 独有生命周期。
3. README 里对 Gemini 的能力说明需要继续与实现保持同步。

## 结论

Gemini CLI **当前属于已支持对象**，但仍有 Gemini 专属事件与项目级配置覆盖问题待完善。详细设计与根因分析见 [gemini-hooks-design.md](./gemini-hooks-design.md)。
