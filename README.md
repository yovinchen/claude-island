<div align="center">
  <img src="ClaudeIsland/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">Claude Island</h3>
  <p align="center">
    macOS Notch 悬浮窗应用 — 实时监控 Claude Code、Codex、Gemini、Cursor 等 AI 编程工具
    <br />
    <br />
    <a href="https://github.com/farouqaldori/claude-island/releases/latest" target="_blank" rel="noopener noreferrer">
      <img src="https://img.shields.io/github/v/release/farouqaldori/claude-island?style=rounded&color=white&labelColor=000000&label=release" alt="Release Version" />
    </a>
    <a href="#" target="_blank" rel="noopener noreferrer">
      <img alt="GitHub Downloads" src="https://img.shields.io/github/downloads/farouqaldori/claude-island/total?style=rounded&color=white&labelColor=000000">
    </a>
  </p>
</div>

## 功能特性

- **Notch 悬浮窗** — 仿 Dynamic Island 风格，从 MacBook 刘海区域弹出
- **多工具支持** — Claude Code、Codex CLI、Gemini CLI、Cursor、OpenCode、Copilot
- **实时会话监控** — 同时追踪多个 AI 编程工具的会话状态
- **权限审批** — 直接在 Notch 中批准/拒绝工具执行请求
- **聊天记录** — 完整对话历史，支持 Markdown 渲染
- **智能通知** — 任务完成自动展开、鼠标离开自动收起、空闲自动隐藏
- **用量显示** — API 速率限制与上下文窗口用量环形指示器
- **Hook 自动修复** — 其他工具覆盖 Hook 配置时可选自动修复
- **全局快捷键** — `⌘⇧I` 切换 Notch 展开/收起
- **多语言** — 支持英文和简体中文
- **用户可控的 Hook** — 首次启动时需用户明确同意才注入 Hook

## 系统要求

- macOS 15.6+
- Xcode 16.0+（从源码构建时需要）
- 至少安装一个支持的 AI 编程工具

## 安装

### 直接下载

从 [Releases](https://github.com/farouqaldori/claude-island/releases/latest) 下载最新 `.dmg` 文件，拖入 `/Applications` 即可。

### 从源码构建

#### 1. 克隆仓库

```bash
git clone https://github.com/farouqaldori/claude-island.git
cd claude-island
```

#### 2. 解析依赖

项目使用 Swift Package Manager 管理依赖。Xcode 首次打开会自动解析，也可手动触发：

```bash
xcodebuild -resolvePackageDependencies -project ClaudeIsland.xcodeproj
```

依赖列表：
- [Sparkle](https://github.com/sparkle-project/Sparkle) — 自动更新
- [swift-markdown](https://github.com/swiftlang/swift-markdown) — Markdown 渲染
- [Mixpanel](https://github.com/mixpanel/mixpanel-swift) — 匿名使用统计

#### 3. 构建

**Xcode 图形界面：**

```
打开 ClaudeIsland.xcodeproj → 选择 Scheme "ClaudeIsland" → ⌘B（构建）或 ⌘R（运行）
```

**命令行构建（无签名）：**

```bash
xcodebuild \
  -project ClaudeIsland.xcodeproj \
  -scheme ClaudeIsland \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

构建产物位于：

```
~/Library/Developer/Xcode/DerivedData/ClaudeIsland-*/Build/Products/Release/ClaudeIsland.app
```

**带签名构建（用于分发）：**

```bash
xcodebuild \
  -project ClaudeIsland.xcodeproj \
  -scheme ClaudeIsland \
  -configuration Release \
  DEVELOPMENT_TEAM="你的团队ID" \
  build
```

#### 4. 运行

```bash
open ~/Library/Developer/Xcode/DerivedData/ClaudeIsland-*/Build/Products/Release/ClaudeIsland.app
```

或在 Xcode 中直接按 `⌘R` 运行。

## 本地打包测试

### 生成 DMG 安装包

项目提供了打包脚本，可一键生成 DMG：

```bash
# 先构建 Release 版本
xcodebuild \
  -project ClaudeIsland.xcodeproj \
  -scheme ClaudeIsland \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

# 找到构建产物
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ClaudeIsland-*/Build/Products/Release -name "ClaudeIsland.app" -maxdepth 1)

# 创建 DMG
hdiutil create -volname "ClaudeIsland" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  ClaudeIsland.dmg
```

### 本地测试流程

1. **构建并运行**：在 Xcode 中 `⌘R`，应用会自动出现在 Notch 区域
2. **首次启动**：弹出 Hook 设置界面，自动检测已安装的 AI 工具
3. **安装 Hook**：选择要集成的工具，点击"安装"
4. **触发测试**：打开终端运行 Claude Code 或其他 AI 工具，观察 Notch 状态变化
5. **权限审批测试**：在 AI 工具中触发需要权限的操作（如文件编辑），在 Notch 中审批
6. **快捷键测试**：按 `⌘⇧I` 切换 Notch 展开/收起

### 调试技巧

- 在 Xcode 控制台查看实时日志输出
- Hook 通信通过 Unix Socket `/tmp/claude-island.sock` 进行
- 可使用 `socat` 模拟 Hook 事件进行调试：

```bash
echo '{"type":"session_start","session_id":"test"}' | socat - UNIX-CONNECT:/tmp/claude-island.sock
```

## 项目结构

```
ClaudeIsland/
├── App/                          # 应用生命周期（AppDelegate、WindowManager）
├── Core/                         # 设置、NotchViewModel、NotchActivityCoordinator
├── Models/                       # SessionState、ChatMessage、SessionPhase
├── Services/
│   ├── Hooks/                    # Hook 安装器、Socket 服务器、文件监听、自动修复
│   ├── Session/                  # 会话监控、对话解析器
│   ├── State/                    # SessionStore（中央状态管理 Actor）
│   ├── Usage/                    # UsageDataManager（API 用量追踪）
│   ├── Sound/                    # SoundPackManager（通知音效）
│   ├── Shared/                   # 快捷键管理、进程执行器
│   ├── Codex/                    # Codex CLI 集成
│   ├── Tmux/                     # Tmux 会话管理
│   └── ...
├── UI/
│   ├── Views/                    # NotchView、菜单视图、Hook 设置、聊天视图
│   ├── Components/               # 用量环、状态图标、Markdown 渲染器
│   └── Window/                   # Notch 窗口、窗口控制器
├── Resources/
│   ├── en.lproj/                 # 英文本地化
│   └── zh-Hans.lproj/           # 简体中文本地化
└── Utilities/

ClaudeIslandBridge/               # Swift CLI 桥接（替代 Python Hook 脚本）
├── main.swift                    # 入口 — 读取 stdin JSON，通过 Socket 转发
├── SocketClient.swift            # Unix Domain Socket 客户端
├── EventMapper.swift             # 将各工具事件映射为统一协议
└── TTYDetector.swift             # 终端检测
```

## 工作原理

### 首次启动

首次启动时，Notch 会弹出 **Hook 设置** 界面。应用会自动检测系统中安装了哪些 AI 工具，并让你选择要集成哪些。**在你点击"安装"之前不会写入任何 Hook。**

你也可以跳过设置，之后在"设置"中配置。

### Hook 通信机制

对于每个启用的工具，Claude Island 会在该工具的配置文件中写入一条 Hook 条目（如 `~/.claude/settings.json`）。当工具触发事件（会话开始、工具使用、权限请求等）时，Hook 脚本会将 JSON 数据发送到 Unix Socket `/tmp/claude-island.sock`，应用解码事件后实时更新 UI。

### 权限审批流程

1. AI 工具请求执行某个操作（如 `Bash`、`Edit`）
2. Hook 发送 `PermissionRequest` 事件并保持 Socket 连接
3. Notch 展开，显示工具详情和"批准"/"拒绝"按钮
4. 用户点击后，响应通过同一 Socket 连接返回
5. AI 工具收到决定并继续执行

### 支持的工具

| 工具 | 配置文件 | Hook 类型 |
|---|---|---|
| Claude Code | `~/.claude/settings.json` | Python 脚本（`command`） |
| Codex CLI | `~/.codex/hooks.json` | Python 脚本（`bash`） |
| Gemini CLI | `~/.gemini/settings.json` | Bridge CLI（`command`） |
| Cursor | `~/.cursor/hooks.json` | Bridge CLI（`command`） |
| OpenCode | `~/.config/opencode/plugins/claude-island.js` | JS 插件文件 |
| Copilot | `~/.copilot/config.json` | Bridge CLI（`command`） |

### Hook 管理

- **设置菜单** → "AI 工具 Hooks" 区域显示各工具的状态
- 点击工具行可 **启用/禁用** 对应的 Hook
- "修复全部" 按钮可为所有已启用的工具重新安装 Hook
- "自动修复 Hook" 开关 — 开启后，当 Hook 被其他工具移除时自动重新安装

## 统计分析

Claude Island 使用 Mixpanel 进行匿名使用统计：

- **App Launched** — 应用版本、构建号、macOS 版本
- **Session Started** — 检测到新的 AI 会话

不收集任何个人数据或对话内容。

## 许可证

Apache 2.0
