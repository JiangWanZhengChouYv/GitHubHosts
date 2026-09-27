# GitHubHosts

GitHubHosts 是 [GitHub520](https://github.com/521xueweihan/GitHub520) 的原生 macOS 桌面版。
它把 GitHub520 原本「复制内容 → `sudo` 手动编辑 `/etc/hosts` → 手动刷新 DNS」的繁琐流程，
变成点一下按钮就能完成的一键操作。

## 功能

- 一键从 `https://raw.hellogithub.com/hosts` 拉取最新 hosts 记录
- 等宽字体预览，行内域名与 IP 对齐可读
- 一键写入 `/etc/hosts`（写入到独立标记区块内，重复应用自动替换，不产生重复）
- 写入后自动刷新 DNS 缓存（`killall -HUP mDNSResponder`）
- 菜单栏常驻，关闭窗口后仍可快速操作

## 环境要求

- macOS 13.0 或更高版本
- 构建需要：
  - Xcode（含命令行工具 `xcodebuild`）
  - [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`

> 运行时不需要安装 XcodeGen，它只在构建阶段用于从 `project.yml` 生成 Xcode 工程。

## 构建

在项目根目录执行：

```bash
./build.sh
```

脚本会先调用 `xcodegen generate` 生成 `GitHubHosts.xcodeproj`，再用 `xcodebuild` 构建 Release 版本，
最后把产物拷贝到 `dist/` 目录。

产物路径：

```
dist/GitHubHosts.app
```

## 运行

```bash
open dist/GitHubHosts.app
```

也可以把 `dist/GitHubHosts.app` 拖入「应用程序」文件夹后双击运行。

## 首次打开被 Gatekeeper 拦截怎么办

本应用使用 ad-hoc 签名、**未经 Apple 公证**，因此首次打开时系统可能提示
「无法打开，因为 Apple 无法检查其是否包含恶意软件」或「已损坏，应将其移到废纸篓」。
这是未签名 / 未公证应用的**正常现象**，不是应用本身的问题。可按以下任一方式处理：

**方式一：右键打开（推荐）**

1. 在访达中找到 `GitHubHosts.app`
2. 按住 Control 键点击（或右键）应用图标，选择「打开」
3. 在弹出的对话框中再次点击「打开」

之后再双击即可正常启动。

**方式二：移除隔离属性（终端）**

如果已把应用拖入「应用程序」文件夹，可在终端执行：

```bash
xattr -cr /Applications/GitHubHosts.app
```

执行完成后再双击应用即可打开。

如果应用仍在 `dist/` 目录中，也可以先对其执行：

```bash
xattr -cr dist/GitHubHosts.app
```

## 关于管理员授权

首次点击「应用到 hosts」时，系统会弹出管理员授权框（类似 `sudo` 的密码提示）。
这是为了写入 `/etc/hosts` 并刷新 DNS。

写入 `/etc/hosts` 与刷新 DNS **共用同一次授权**，整个过程只会弹出一次授权框，不会反复打扰。

## 网络 / 代理说明

应用使用 `URLSession` 默认配置，会**自动遵循系统代理设置**。

如果拉取失败，请检查：

- 系统代理是否正常工作
- 网络能否访问 `raw.hellogithub.com`

可以先用下面的命令自检：

```bash
curl https://raw.hellogithub.com/hosts
```

若能正常返回 hosts 内容，说明网络与代理没有问题；否则请先修复网络 / 代理后再重试。

## 数据来源与致谢

- 数据来源：[GitHub520](https://github.com/521xueweihan/GitHub520)（`https://raw.hellogithub.com/hosts`）
- 产品形态参考：[SwitchHosts](https://github.com/oldj/SwitchHosts)

感谢以上开源项目。

## 卸载 / 还原

应用写入的 GitHub520 内容位于 `/etc/hosts` **末尾**，被以下两行标记包裹：

```
# GitHub520 Host Start
...
# GitHub520 Host End
```

如需还原，只需手动删除这两行标记及其之间的全部内容即可（可用 `sudo vi /etc/hosts` 编辑）。
删除后建议执行一次 DNS 刷新：

```bash
sudo killall -HUP mDNSResponder
```

最后把 `GitHubHosts.app` 删掉即可完成卸载。应用不会在系统其他位置留下常驻服务。
