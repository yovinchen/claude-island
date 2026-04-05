# Google Antigravity — 差距分析

> 官方入门: https://codelabs.developers.google.com/getting-started-google-antigravity
> 官方站点: https://antigravity.google/
> 分析日期: 2026-04-06

## 当前仓库状态

| 项目 | 状态 | 说明 |
|------|------|------|
| `SessionSource` / `HookSource` | ❌ | 仓库中没有 Antigravity 的枚举、安装器、事件映射 |
| 宿主识别 | ❌ | 当前未检测 Antigravity app 或其终端/IDE 进程 |
| 文档/README | ❌ | README 和 docs 里都还没有 Antigravity 接入说明 |

## 官方可用扩展面

| 能力 | 官方状态 | 说明 |
|------|------|------|
| 本地 hooks | 未见公开文档 | 官方入门材料没有提供独立 hook schema |
| Agent Manager / Artifacts | ✅ | Antigravity 通过任务清单、实现计划、walkthrough 等 artifacts 暴露 agent 过程 |
| 命令自动执行策略 | ✅ | 官方入门材料展示了 terminal auto execution、allow list、deny list |
| Browser extension / verification | ✅ | 官方强调浏览器验证与 walkthrough 产物 |
| VS Code / Cursor 设置导入 | ✅ | 安装流程支持从现有编辑器导入设置 |

## 可替代实现方式

1. 若官方继续不开放 hooks，最现实的替代方案是读取 artifact / plan / walkthrough 文件或接入未来的 session API。
2. 也可以从命令审批层切入，利用 allow list / deny list 变化推断“等待审批”状态，但这需要官方暴露可读配置。
3. 浏览器验证链路如果开放记录文件，也可以作为 `Stop` / `PostToolUse` 的替代信号。

## 对 Claude Island 的主要 gap

1. 没有本地 hook 协议，现有 `HookInstaller` 无法直接复用。
2. Antigravity 更偏“agent-first IDE + artifacts”，需要新增 artifact/session 解析器。
3. 需要先确定 Antigravity 的配置目录、会话日志、权限审批数据是否有稳定落盘格式。

## 结论

Antigravity **当前不支持接入**。官方公开能力更像“任务产物 + 审批策略 + 浏览器验证”，还不是类似 Claude/Cursor/Windsurf 的本地 hooks 模型。

## 基于本地代码的实现可行性

**可行性评级**: 低（直连） / 中（artifact watcher）

**可直接复用**
- 只能复用 `HookEvent`/`SessionStore` 的“统一事件消费端”；`HookInstaller`、`PermissionHandler`、`HookSocketServer` 基本复用不上。

**可实施方案**
1. 如果 Antigravity 有稳定产物目录，可新增 watcher，把 artifact 变化转成 `SessionStart` / `Stop` / `Notification`。
2. 审批类场景更可能需要读取 allow/deny 配置或浏览器验证产物，而不是复用现有 socket 审批。

**主要阻塞**
- 目前缺少公开、稳定的本地事件输入面。没有输入面，就没有 source 可接。
