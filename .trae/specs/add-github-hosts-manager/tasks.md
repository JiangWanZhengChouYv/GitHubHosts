# Tasks

- [x] Task 1: 搭建 Xcode 工程骨架（可编译的空壳 App）
  - [x] SubTask 1.1: 创建 `project.yml`（XcodeGen）：macOS 13.0+、bundle id `com.markzhang.GitHubHosts`、关闭 App Sandbox、ad-hoc 签名、`GitHubHosts` target 与 `GitHubHostsTests` 测试 target
  - [x] SubTask 1.2: 创建目录与占位源码：`GitHubHosts/GitHubHostsApp.swift`、`Views/ContentView.swift`、`Resources/Assets.xcassets`、`GitHubHostsTests/HostPrintTests.swift`
  - [x] SubTask 1.3: 执行 `xcodegen generate` 并 `xcodebuild -scheme GitHubHosts build`，确认编译通过

- [x] Task 2: 实现 hosts 拉取服务 `Services/HostsFetcher.swift`
  - [x] SubTask 2.1: `URLSession` 拉取 `https://raw.hellogithub.com/hosts`，校验 HTTP 状态与内容含标记
  - [x] SubTask 2.2: 定义错误类型 `FetchError`（网络失败/非 2xx/内容无效），提供可读文案
  - [x] SubTask 2.3: 缓存写入 `Application Support/GitHubHosts/last_fetch.hosts`，时间戳写入 `UserDefaults`，启动时读取缓存

- [x] Task 3: 实现 `/etc/hosts` 合并逻辑 `Services/HostsFileManager.swift`
  - [x] SubTask 3.1: 纯函数 `stripExistingBlock(from:)`：移除已有 GitHub520 区块（含标记行与相邻空行）
  - [x] SubTask 3.2: 纯函数 `merge(original:block:)`：清理旧块后在文件末尾追加新区块，保证幂等；保证原文件其他内容与换行风格不被破坏
  - [x] SubTask 3.3: `readSystemHosts()` 读取 `/etc/hosts`；`containsBlock(_:)` / `isUpToDate(_:)` 用于状态判断
  - [x] SubTask 3.4: 为上述纯函数编写单元测试（首插/替换/多处残留/空文件/末尾无换行）

- [x] Task 4: 实现提权执行器 `Services/PrivilegedExecutor.swift`
  - [x] SubTask 4.1: 将合并后的内容写到用户临时文件，构造一次 AppleScript：`do shell script "/bin/cp <tmp> /etc/hosts && /usr/bin/killall -HUP mDNSResponder" with administrator privileges`
  - [x] SubTask 4.2: 通过 `Process` 调用 `/usr/bin/osascript`，捕获退出码与 stderr，返回成功/失败/已取消（错误码 -128）
  - [x] SubTask 4.3: 提供 `flushDNSOnly()`（仅刷新 DNS，同样弹窗授权）

- [x] Task 5: 实现状态编排 `Models/HostsStore.swift`
  - [x] SubTask 5.1: `@MainActor ObservableObject`，暴露 `remoteContent`、`lastUpdated`、`status`、`errorMessage`、`isBusy`
  - [x] SubTask 5.2: 整合拉取、应用、刷新动作，并在应用成功后重新计算状态

- [x] Task 6: 实现主窗口 UI `Views/ContentView.swift`
  - [x] SubTask 6.1: 顶部展示来源 URL 与「获取最新」按钮，含加载中状态
  - [x] SubTask 6.2: 中部预览区（等宽字体、可滚动）展示待写入内容
  - [x] SubTask 6.3: 底部状态栏 + 「应用到 hosts」「仅刷新 DNS」按钮，错误以可读文案呈现

- [x] Task 7: 实现菜单栏 `Views/MenuBarView.swift` 与 Scene 配置
  - [x] SubTask 7.1: `MenuBarExtra` 菜单项：打开主窗口（`openWindow`）、立即更新并应用、仅刷新 DNS、退出
  - [x] SubTask 7.2: 在 `GitHubHostsApp.swift` 中以 `Window`/`WindowGroup` 承载主窗口，关闭窗口不退出应用

- [x] Task 8: 构建脚本与文档
  - [x] SubTask 8.1: 编写 `build.sh`（xcodegen generate + xcodebuild 产出 `GitHubHosts.app`），产物路径固定并打印
  - [x] SubTask 8.2: 编写 `README.md`：构建方法、运行方法、Gatekeeper 被拦截时的信任与 `xattr -cr` 步骤、代理说明
  - [x] SubTask 8.3: 创建/更新 `AGENTS.md`：记录工程规则、构建与测试命令，并追加本次已完成项

- [x] Task 9: 端到端验证
  - [x] SubTask 9.1: `xcodebuild test` 全部单测通过
  - [x] SubTask 9.2: `./build.sh` 成功产出可运行的 `.app`
  - [x] SubTask 9.3: 用真实网络验证拉取与预览；写入 `/etc/hosts` 需用户授权，验证后确认区块唯一且 DNS 已刷新

# Task Dependencies

- Task 2、Task 3、Task 4 相互独立，可在 Task 1 完成后并行开展
- Task 5 依赖 Task 2、Task 3、Task 4
- Task 6、Task 7 依赖 Task 5
- Task 8、Task 9 依赖 Task 1（Task 9 依赖全部前序任务）
