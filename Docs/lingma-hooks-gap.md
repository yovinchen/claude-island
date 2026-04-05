# Lingma / 通义灵码 — 差距分析

> 项目规则: https://help.aliyun.com/zh/lingma/user-guide/rules
> 自定义智能体: https://help.aliyun.com/zh/lingma/user-guide/custom-agent
> 产品概览: https://help.aliyun.com/zh/lingma/product-overview/introduction-of-lingma
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前没有 Lingma / 通义灵码 接入源 |
| README / docs | ❌ | 仓库暂无 Lingma 兼容性说明 |
| 宿主支持 | ❌ | 目前未识别 Lingma IDE 进程或配置目录 |

## 官方可用扩展面

| 能力 | 官方状态 | 说明 |
|------|------|------|
| 生命周期 hooks | 未见公开文档 | 当前官方文档主打规则与自定义智能体，而非 hook callback |
| 项目规则 | ✅ | `.lingma/rules` 支持 Manual / Model Decision / Always / Specific Files |
| 自定义智能体 | ✅ | 支持 `create-agent`、独立工具权限、subagent 调度 |
| IDE / 插件宿主 | ✅ | 支持 JetBrains、VS Code、Visual Studio、Lingma IDE |
| MCP | ✅ | 产品文档列出 MCP 能力 |

## 可替代实现方式

1. 用 `.lingma/rules` 作为“静态规则注入”替代 hook。
2. 用自定义智能体的工具权限和 subagent 能力替代部分审批场景。
3. 如果未来 Lingma 暴露会话日志或脚本接口，再评估转为 watcher / hook source。

## 对 Claude Island 的主要 gap

1. 官方没有公开 hook schema，无法直接走现有安装器路线。
2. Lingma 的规则系统更接近 prompt/rule 注入，不是 deterministic event callback。
3. 要支持 Lingma，可能需要单独做 `.lingma/rules` 管理和自定义智能体桥接，而不是复用 `HookInstaller`。

## 结论

Lingma **当前不支持接入**。官方公开能力以 `.lingma/rules`、自定义智能体和 MCP 为主，尚未提供可直接接入 Claude Island 的本地 hooks 机制。

## 基于本地代码的实现可行性

**可行性评级**: 低（hooks） / 中（规则同步）

**可直接复用**
- 只能复用 UI 和统一事件消费端；`HookInstaller` / `HookSocketServer` / `PermissionHandler` 基本不适配。

**可实施方案**
1. 如果目标是“给 Lingma 注入项目约束”，可做 `.lingma/rules` 生成器，而不是新增 hooks source。
2. 如果后续需要会话监控，优先找 MCP/session 日志，再考虑 watcher。

**主要阻塞**
- Lingma 的公开扩展面不是事件回调型，本地现有 hooks 骨架很难直接复用。
