# GitHubHosts（GitHub520 桌面版）Spec

## Why

GitHub520 通过维护一份 hosts 记录来解决 GitHub 访问慢、图片加载不出的问题，但其使用方式仍是「复制内容 → sudo 手动编辑 /etc/hosts → 手动刷新 DNS」，门槛高、易出错、无法自动更新。用户希望有一款原生 macOS 应用，像 SwitchHosts 那样一键完成「拉取最新记录 → 写入 /etc/hosts → 刷新 DNS」。

本 Spec 采用**精简版**范围：只服务 GitHub520 单一数据源，不引入多条目/分组/回收站等 SwitchHosts 的完整功能。

## What Changes

- 新建 Xcode 工程（SwiftUI macOS App，工程文件由 XcodeGen 的 `project.yml` 生成），应用名 `GitHubHosts`。
- 主窗口：拉取 GitHub520 远程 hosts → 预览 → 一键应用到 `/etc/hosts` → 刷新 DNS。
- 菜单栏常驻：打开主窗口、立即更新并应用、仅刷新 DNS、退出。
- 写入 `/etc/hosts` 与刷新 DNS 通过 AppleScript（`do shell script ... with administrator privileges`）弹窗授权完成，两者合并为**一次**授权。
- 写入采用标记区块（`# GitHub520 Host Start` / `# GitHub520 Host End`），重复应用自动替换旧区块，不产生重复。
- 持久化上次拉取内容与更新时间，重启后可继续预览/重新应用。
- 提供构建脚本与 README（含未签名应用的 xattr 信任步骤），并把已完成项记录到 `AGENTS.md`。

## Impact

- Affected specs: 新增能力，无既有 Spec 被修改。
- Affected code: 全新工程，主要文件：
  - `project.yml`、`GitHubHosts.xcodeproj`（生成物）
  - `GitHubHosts/GitHubHostsApp.swift`（App 入口、Scene/菜单栏）
  - `GitHubHosts/Views/ContentView.swift`、`MenuBarView.swift`
  - `GitHubHosts/Models/HostsStore.swift`（状态与业务编排）
  - `GitHubHosts/Services/HostsFetcher.swift`、`HostsFileManager.swift`、`PrivilegedExecutor.swift`
  - `GitHubHostsTests/`（纯逻辑单元测试）
  - `build.sh`、`README.md`、`AGENTS.md`

## 技术约束

- 最低系统版本：macOS 13.0（`MenuBarExtra` 与 `Window` Scene 需要 13+）。
- 语言/框架：Swift + SwiftUI，无第三方依赖。
- App Sandbox 关闭（需要读取 `/etc/hosts` 并调用 `osascript` 子进程）；采用 ad-hoc 签名。
- 网络：使用 `URLSession` 默认配置，遵循系统代理设置。
- 数据源常量：`https://raw.hellogithub.com/hosts`（另记录 JSON 端点 `https://raw.hellogithub.com/hosts.json` 备用，本版本不解析）。
- 标记常量：开始 `# GitHub520 Host Start`，结束 `# GitHub520 Host End`。
- 本地缓存路径：`~/Library/Application Support/GitHubHosts/last_fetch.hosts`；时间戳存 `UserDefaults`。

## ADDED Requirements

### Requirement: 拉取 GitHub520 远程 hosts

系统 SHALL 能从 `https://raw.hellogithub.com/hosts` 拉取最新 hosts 内容，并记录拉取时间。

#### Scenario: 拉取成功

- **WHEN** 用户点击「获取最新」
- **THEN** 应用显示拉取到的 hosts 内容与「更新时间」为本次拉取时间

#### Scenario: 拉取失败

- **WHEN** 网络不可用或返回非 2xx
- **THEN** 应用显示可读的错误信息，且保留并展示上一次的缓存内容（若有）

#### Scenario: 内容校验

- **WHEN** 拉取到的内容为空或不包含 GitHub520 标记
- **THEN** 应用视为无效内容并提示，不覆盖缓存

### Requirement: 内容预览

系统 SHALL 以等宽字体展示待写入的 hosts 内容，并显示来源 URL 与更新时间。

#### Scenario: 展示明细

- **WHEN** 预览区有内容
- **THEN** 每行域名与 IP 对齐可读，且不截断为不可辨认的文本

### Requirement: 应用到 /etc/hosts

系统 SHALL 把 GitHub520 内容以标记区块写入 `/etc/hosts`；写入前移除已存在的旧区块，保证幂等。

#### Scenario: 首次应用

- **WHEN** `/etc/hosts` 中不存在 GitHub520 区块且用户点击「应用到 hosts」
- **THEN** 授权后区块被追加到文件末尾，其余原有内容保持不变

#### Scenario: 重复应用（幂等）

- **WHEN** `/etc/hosts` 中已存在旧 GitHub520 区块且用户再次应用
- **THEN** 旧区块被完整替换为新内容，文件中区块数量恒为 1，无重复行

#### Scenario: 用户取消授权

- **WHEN** 用户在系统授权弹窗中点击取消
- **THEN** `/etc/hosts` 不被修改，界面提示「已取消」

### Requirement: 刷新 DNS 缓存

系统 SHALL 在写入成功后执行 `killall -HUP mDNSResponder` 刷新 DNS，并与写入共用同一次管理员授权。

#### Scenario: 合并授权

- **WHEN** 用户点击「应用到 hosts」
- **THEN** 整个流程仅弹出一次系统授权框

#### Scenario: 单独刷新

- **WHEN** 用户在菜单栏选择「仅刷新 DNS」
- **THEN** 执行刷新并给出结果提示

### Requirement: 菜单栏常驻

系统 SHALL 在菜单栏提供图标，其菜单包含：打开主窗口、立即更新并应用、仅刷新 DNS、退出。

#### Scenario: 关闭窗口后仍可用

- **WHEN** 用户关闭主窗口
- **THEN** 应用不退出，菜单栏图标仍可操作

### Requirement: 状态感知

系统 SHALL 显示 `/etc/hosts` 当前是否已包含 GitHub520 区块，以及该区块内容是否与最新拉取内容一致。

#### Scenario: 展示状态

- **WHEN** 主窗口打开
- **THEN** 以「未写入 / 已写入·已是最新 / 已写入·有更新」之一呈现当前状态

### Requirement: 持久化

系统 SHALL 缓存上次成功拉取的内容与时间。

#### Scenario: 冷启动恢复

- **WHEN** 应用重启且尚未联网拉取
- **THEN** 预览区展示缓存内容及其更新时间，且「应用」按钮可用

### Requirement: 可构建性与分发说明

系统 SHALL 提供可复现的构建方式与运行说明。

#### Scenario: 命令行构建

- **WHEN** 执行 `./build.sh`
- **THEN** 通过 `xcodegen` 生成工程并 `xcodebuild` 产出 `GitHubHosts.app`

#### Scenario: 首次打开被系统拦截

- **WHEN** 用户把未签名应用拖入「应用程序」并双击被 Gatekeeper 拦截
- **THEN** README 提供 `xattr -cr` 去除隔离属性的步骤及右键打开的信任方法

## MODIFIED Requirements

无。

## REMOVED Requirements

无。

## 非目标（Non-Goals）

以下为明确不做（精简版边界）：

- 多 hosts 条目管理、分组/文件夹、回收站（SwitchHosts 的完整能力）
- 语法高亮编辑器、查找替换、导入导出
- 特权助手工具（SMJobBless）静默写入
- 自行探测最优 IP、修改 GitHub520 数据源内容
- Windows / Linux 版本
