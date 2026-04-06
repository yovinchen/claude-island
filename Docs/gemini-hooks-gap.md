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
| 项目级配置诊断 | ✅ | 新 Gemini 会话会提示工作区 `.gemini/settings.json`，且在该文件存在时会一并纳入受管安装 |

## 已知剩余 gap

1. 仍需持续核对 Gemini 原生事件名，避免把 Claude 风格事件写回 Gemini 配置。
2. README 里对 Gemini 的能力说明需要继续与实现保持同步。

## 结论

Gemini CLI **当前属于已支持对象**，但仍有 Gemini 专属事件与项目级配置覆盖问题待完善。详细设计与根因分析见 [gemini-hooks-design.md](./gemini-hooks-design.md)。

## 基于本地代码的实现可行性

**可行性评级**: 高

**可直接复用**
- `GeminiHookSource` 已是单独安装器，`EventMapper` 也已有 Gemini 专属别名分支。
- UI、repair、source 列表已完整包含 `.gemini`，后续只是在既有 source 上补事件。

**最小实现方案**
1. 继续补 Gemini 专属事件的字段提取与展示细节。
2. 当前项目级 `.gemini/settings.json` 已在存在时纳入受管路径；后续仅再评估 system 级 `/Library/Application Support/GeminiCli/settings.json` 是否值得托管。
3. 保持 Gemini 为“无独立 PermissionRequest”的模型，不要勉强对齐 Claude。

**主要阻塞**
- 阻塞主要是 Gemini 事件语义与 Claude 不同，需要克制地做 source-aware 映射，不能走统一粗暴别名。
