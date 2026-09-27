import Foundation

/// 提权执行过程中可能出现的错误。
enum PrivilegeError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "已取消"
        case .failed(let message):
            return "执行失败：\(message)"
        }
    }
}

/// 通过一次性 AppleScript 授权完成「写入 /etc/hosts + 刷新 DNS」。
struct PrivilegedExecutor {

    /// 计算「把 GitHub520 区块合并进当前 hosts 后」的完整文件内容。
    ///
    /// 只替换 `# GitHub520 Host Start` ~ `# GitHub520 Host End` 区块，
    /// 其余内容（`localhost`、用户自己添加的记录等）一律保留。
    /// 纯计算、不写文件，便于单元测试。
    func mergedSystemHosts(block: String,
                           fileManager: HostsFileManager = HostsFileManager()) throws -> String {
        guard let current = fileManager.readSystemHosts() else {
            throw PrivilegeError.failed("无法读取 \(fileManager.hostsPath)")
        }
        return HostsMerge.merge(original: current, block: block)
    }

    /// 把 GitHub520 区块合并后写入 `/etc/hosts`，并（可选）在同一次授权中刷新 DNS。
    ///
    /// ⚠️ 写入的必须是「合并后的完整文件」，绝不能把区块本身直接写进去——
    /// 那会整体覆盖 `/etc/hosts`，清空用户原有的 hosts 记录。
    func applyHosts(block: String, refreshDNS: Bool) async throws {
        let merged = try mergedSystemHosts(block: block)
        try await writeSystemHosts(merged, refreshDNS: refreshDNS)
    }

    /// 仅刷新 DNS 缓存（同样需要一次管理员授权）。
    func flushDNSOnly() async throws {
        let script = "do shell script \"/usr/bin/killall -HUP mDNSResponder\" with administrator privileges"
        try await runAppleScript(script)
    }

    // MARK: - Private

    /// 用一次 AppleScript 授权把完整 hosts 内容写入系统文件，并可选刷新 DNS。
    private func writeSystemHosts(_ fullContent: String, refreshDNS: Bool) async throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("githubhosts-\(UUID().uuidString).hosts", isDirectory: false)

        try fullContent.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        var script = "do shell script \"/bin/cp \" & quoted form of \(appleScriptString(tmpURL.path)) & \" \(HostsFileManager.systemHostsPath)\""
        if refreshDNS {
            script += " & \" && /usr/bin/killall -HUP mDNSResponder\""
        }
        script += " with administrator privileges"

        try await runAppleScript(script)
    }

    /// 把字符串编码为 AppleScript 字符串字面量（转义反斜杠与双引号）。
    private func appleScriptString(_ raw: String) -> String {
        let escaped = raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// 在后台线程调用 `/usr/bin/osascript -e <script>`，并桥接到 async。
    private func runAppleScript(_ script: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]

                let errorPipe = Pipe()
                process.standardError = errorPipe
                process.standardOutput = Pipe()

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: PrivilegeError.failed(error.localizedDescription))
                    return
                }

                process.waitUntilExit()

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: ())
                } else if errorText.contains("User canceled") || errorText.contains("-128") {
                    continuation.resume(throwing: PrivilegeError.cancelled)
                } else {
                    let message = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: PrivilegeError.failed(
                        message.isEmpty ? "退出码 \(process.terminationStatus)" : message
                    ))
                }
            }
        }
    }
}
