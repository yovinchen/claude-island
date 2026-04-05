# Claudix — 差距分析

> 官方仓库: https://github.com/Claudix/claudix
> VS Code Marketplace: https://marketplace.visualstudio.com/
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前无 Claudix 接入 |
| 宿主支持 | 间接 | 若 Claudix 运行在 VS Code，可借助现有 VS Code 聚焦逻辑，但不是独立集成 |
| 文档沉淀 | ❌ | 仓库暂无 Claudix gap 文档 |

## 官方可用扩展面

| 能力 | 状态 | 说明 |
|------|------|------|
| 独立 hooks 文档 | 未发现 | 当前没有稳定、公开、可引用的 hooks schema |
| 扩展方式 | 有限 | 公开资料更偏向 VS Code 扩展本体，而非 hook API |

## 可替代实现方式

1. 如果 Claudix 内部实质上是某个 CLI/SDK 的前端壳层，应优先接它底层 agent 的 hooks，而不是扩展表层。
2. 如果未来 Claudix 暴露 extension API / event bus，可新增 watcher 或 stdout bridge。

## 结论

Claudix **当前不支持接入**。截至本次审计，未发现可直接对接 Claude Island 的官方 hooks 文档。

## 基于本地代码的实现可行性

**可行性评级**: 低

**可直接复用**
- 目前只能复用 VS Code 宿主聚焦与统一事件消费端，安装器和审批链路都没有明确落点。

**可实施方案**
1. 若后续确认 Claudix 只是某个底层 CLI 的前端，应直接接底层 CLI。
2. 若 Claudix 公开扩展事件，再考虑 watcher / plugin bridge。

**主要阻塞**
- 阻塞点是没有稳定官方输入面，不是本地代码没有可复用模块。
