import Foundation

/// GitHub520 标记区块的纯函数合并逻辑（无任何 I/O，便于单元测试）。
enum HostsMerge {

    static let startMarker = "# GitHub520 Host Start"
    static let endMarker   = "# GitHub520 Host End"

    /// 判断一行（忽略首尾空白）是否为指定标记。
    static func isMarker(_ line: String, _ marker: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == marker
    }

    static func isStartMarker(_ line: String) -> Bool { isMarker(line, startMarker) }
    static func isEndMarker(_ line: String) -> Bool { isMarker(line, endMarker) }

    private static func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 移除文本中「任意」已存在的 GitHub520 区块：
    /// 包含两端标记行、区块内部的空行，以及紧邻区块前后的空行；
    /// 支持重复/残缺（缺少结束标记）的区块。其余内容保持不变。
    static func stripExistingBlock(from text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0

        while i < lines.count {
            if isStartMarker(lines[i]) {
                // 移除紧邻区块之前的空行。
                while let last = result.last, isBlank(last) {
                    result.removeLast()
                }
                // 跳过开始标记，直到结束标记（含），或遇到下一个开始标记 / 文件结尾。
                i += 1
                while i < lines.count {
                    if isEndMarker(lines[i]) {
                        i += 1
                        break
                    }
                    if isStartMarker(lines[i]) {
                        break
                    }
                    i += 1
                }
                // 移除紧邻区块之后的空行。
                while i < lines.count, isBlank(lines[i]) {
                    i += 1
                }
                continue
            }
            result.append(lines[i])
            i += 1
        }

        return result.joined(separator: "\n")
    }

    /// 在移除旧区块后，把新区块追加到文件末尾；保证幂等。
    /// - 剩余内容非空时，用一个空行分隔。
    /// - 结果始终以单个换行结尾，且仅包含一个区块。
    static func merge(original: String, block: String) -> String {
        let base = removingTrailingBlankLines(stripExistingBlock(from: original))
        let newBlock = removingTrailingBlankLines(removingLeadingBlankLines(block))

        if base.isEmpty {
            return newBlock + "\n"
        }
        return base + "\n\n" + newBlock + "\n"
    }

    /// 文本中是否包含 GitHub520 区块（以开始标记为准）。
    static func containsBlock(_ text: String) -> Bool {
        text.components(separatedBy: "\n").contains { isStartMarker($0) }
    }

    /// 提取当前文本中的 GitHub520 区块（从开始标记到结束标记，含）。
    /// 若不存在区块返回 nil。
    static func extractBlock(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { isStartMarker($0) }) else {
            return nil
        }
        let block: ArraySlice<String>
        if let end = lines[start...].firstIndex(where: { isEndMarker($0) }) {
            block = lines[start...end]
        } else {
            block = lines[start...]
        }
        return block.joined(separator: "\n")
    }

    /// 归一化：统一换行符、去除每行首尾空白与首尾空行，用于内容比较。
    static func normalize(_ text: String) -> String {
        let unified = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = unified.components(separatedBy: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        while let last = lines.last, last.isEmpty { lines.removeLast() }
        while let first = lines.first, first.isEmpty { lines.removeFirst() }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private static func removingTrailingBlankLines(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        while let last = lines.last, isBlank(last) {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private static func removingLeadingBlankLines(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        while let first = lines.first, isBlank(first) {
            lines.removeFirst()
        }
        return lines.joined(separator: "\n")
    }
}

/// 负责读写系统 `/etc/hosts` 并判断当前状态。
final class HostsFileManager {

    static let systemHostsPath = "/etc/hosts"

    /// 目标 hosts 文件路径。默认是系统路径，测试时可注入临时文件。
    let hostsPath: String

    init(hostsPath: String = HostsFileManager.systemHostsPath) {
        self.hostsPath = hostsPath
    }

    /// 读取 hosts 文件内容；失败返回 nil。
    func readSystemHosts() -> String? {
        try? String(contentsOfFile: hostsPath, encoding: .utf8)
    }

    /// `/etc/hosts` 中已有的 GitHub520 区块是否与 `latest` 一致。
    func isUpToDate(latest: String) -> Bool {
        guard !latest.isEmpty,
              let current = readSystemHosts(),
              let existingBlock = HostsMerge.extractBlock(from: current) else {
            return false
        }
        return HostsMerge.normalize(existingBlock) == HostsMerge.normalize(latest)
    }
}
