# Pi Coding Agent — 差距分析

> 官方仓库: https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent
> 作者示例扩展: https://gist.github.com/badlogic/8d47e8dbfa9876427670cf207cb330c1
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 当前无 Pi Coding Agent 接入 |
| README / docs | ❌ | 暂无 Pi 相关审计记录 |

## 官方可用扩展面

| 能力 | 状态 | 说明 |
|------|------|------|
| 独立 hooks 文档 | 未发现 | 当前公开资料更偏向 agent toolkit / 扩展 API |
| 扩展命令 API | ✅ | 作者公开示例展示了 `registerCommand` 扩展方式 |
| 内建工具 / 会话系统 | ✅ | 公开资料强调内建 coding tools 与 session persistence |

## 可替代实现方式

1. 若要接 Pi，更像是接其 extension API 或 session store，而不是接 hooks。
2. 也可以考虑把 Pi 当成“底层 agent runtime”，通过命令包装器注入 stdout bridge。

## 结论

Pi Coding Agent **当前不支持接入**。本次只找到扩展 API / toolkit 公开资料，未找到稳定的官方 hooks 规范。

## 基于本地代码的实现可行性

**可行性评级**: 低（直连） / 中（命令包装）

**可直接复用**
- 如果未来选择“包裹 CLI / agent runtime 输出”的方案，可复用 `EventMapper` 下游与统一 session/UI。

**可实施方案**
1. 优先寻找 Pi 的 session store 或命令扩展点。
2. 若只能包裹命令，先做只读 watcher，不要先碰审批。

**主要阻塞**
- 当前没有官方 hooks 规范，所有实现都会偏旁路，维护成本高。
