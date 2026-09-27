# AGENTS.md

本文件面向在本仓库中工作的 AI Agent（以及人类协作者），说明项目结构、构建/测试方式与必须遵守的开发约定。

## 项目概述与技术栈

**GitHubHosts** 是 GitHub520 的原生 macOS 桌面版：一键拉取 GitHub520 的 hosts 记录，
预览后写入 `/etc/hosts` 的标记区块，并刷新 DNS 缓存。

- 语言 / 框架：**Swift + SwiftUI**（无第三方依赖）
- 工程生成：**XcodeGen**，工程文件由 `project.yml` 生成
- 最低系统版本：**macOS 13.0**（依赖 `MenuBarExtra` 与 `Window` Scene）
- 签名方式：**ad-hoc 签名**，不做公证；App Sandbox 关闭（需读取 `/etc/hosts` 并调用 `osascript`）
- 网络：`URLSession` 默认配置，遵循系统代理
- 提权：AppleScript `do shell script ... with administrator privileges`

## 目录结构

```
GitHubHosts/
├── project.yml                       # XcodeGen 工程描述（工程文件的唯一真实来源）
├── GitHubHosts.xcodeproj             # 生成物，勿手改
├── build.sh                          # 构建脚本
├── README.md                         # 面向用户的说明文档
├── AGENTS.md                         # 本文件
├── GitHubHosts/
│   ├── GitHubHostsApp.swift          # App 入口、Scene 与菜单栏
│   ├── Views/
│   │   ├── ContentView.swift         # 主窗口界面
│   │   └── MenuBarView.swift         # 菜单栏菜单
│   ├── Models/
│   │   └── HostsStore.swift          # 状态与业务编排（ObservableObject）
│   └── Services/
│       ├── HostsFetcher.swift        # 远程拉取 + 本地缓存
│       ├── HostsFileManager.swift    # /etc/hosts 读写 + HostsMerge 合并逻辑（幂等，纯函数）
│       └── PrivilegedExecutor.swift  # AppleScript 单次授权执行器
├── GitHubHostsTests/                 # 纯逻辑单元测试
└── dist/                             # 构建产物输出目录（由 build.sh 生成）
```

## 构建命令

```bash
./build.sh
```

该脚本会：`xcodegen generate` → `xcodebuild ... build` → 拷贝产物到 `dist/GitHubHosts.app`。

## 测试命令

```bash
xcodebuild -project GitHubHosts.xcodeproj -scheme GitHubHosts -destination 'platform=macOS' test
```

## 开发约定

- **不要手动修改 `GitHubHosts.xcodeproj`**。它是生成物，所有工程配置都应改在 `project.yml`，
  然后执行 `xcodegen generate` 重新生成。
- **标记常量必须保持一致**：开始标记 `# GitHub520 Host Start`，结束标记 `# GitHub520 Host End`。
  任何地方（写入、解析、检测）都不得改动其文本。
- **`HostsMerge` 的合并逻辑必须保持幂等**：重复应用只会替换旧区块，
  文件中 GitHub520 区块的数量恒为 1，不产生重复行，且不影响其他原有内容。
- **提权统一走 AppleScript**：禁止使用其他提权方式（如 `SMJobBless` 特权助手）。
- **写入 + 刷新 DNS 必须合并为一次授权**：写入 `/etc/hosts` 与 `killall -HUP mDNSResponder`
  应在同一个 `do shell script` 中完成，用户只需授权一次。

## 已完成项

- [x] 搭建 Xcode 工程骨架（XcodeGen + project.yml）
- [x] 实现 hosts 拉取服务 HostsFetcher（含本地缓存）
- [x] 实现 /etc/hosts 合并逻辑 HostsMerge（幂等）与单元测试
- [x] 实现提权执行器 PrivilegedExecutor（AppleScript 单次授权，写入 + 刷新 DNS）
- [x] 实现状态编排 HostsStore
- [x] 实现主窗口 ContentView 与菜单栏 MenuBarView
- [x] 构建脚本 build.sh 与 README（含 xattr 信任步骤）
