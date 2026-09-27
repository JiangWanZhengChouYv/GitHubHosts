import Foundation

/// 拉取 hosts 过程中可能出现的错误。
enum FetchError: LocalizedError {
    case network(String)
    case badStatus(Int)
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return "网络请求失败：\(message)"
        case .badStatus(let code):
            return "服务器返回异常状态码：\(code)"
        case .invalidContent:
            return "返回内容无效（为空或不包含 GitHub520 标记）"
        }
    }
}

/// 一次成功拉取的结果。
struct FetchResult {
    let content: String
    let date: Date
}

/// 负责从 GitHub520 数据源拉取 hosts 内容并做本地缓存。
final class HostsFetcher {

    /// GitHub520 raw hosts 数据源。
    static let sourceURL = URL(string: "https://raw.hellogithub.com/hosts")!

    private let defaults: UserDefaults
    private let lastFetchDateKey = "lastFetchDate"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 缓存文件路径：`~/Library/Application Support/GitHubHosts/last_fetch.hosts`
    static var cacheFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("GitHubHosts", isDirectory: true)
            .appendingPathComponent("last_fetch.hosts", isDirectory: false)
    }

    /// 拉取远程 hosts 内容；成功后写入本地缓存并记录时间。
    func fetch() async throws -> FetchResult {
        var request = URLRequest(url: Self.sourceURL)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FetchError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FetchError.network("无效的响应类型")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.badStatus(http.statusCode)
        }
        guard let content = String(data: data, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              content.contains(HostsMerge.startMarker) else {
            throw FetchError.invalidContent
        }

        let date = Date()
        saveCache(content: content, date: date)
        return FetchResult(content: content, date: date)
    }

    /// 读取本地缓存；若不存在返回 nil。
    func loadCache() -> FetchResult? {
        let url = Self.cacheFileURL
        guard let content = try? String(contentsOf: url, encoding: .utf8),
              !content.isEmpty else {
            return nil
        }
        let date = (defaults.object(forKey: lastFetchDateKey) as? Date) ?? fileModificationDate(of: url) ?? Date()
        return FetchResult(content: content, date: date)
    }

    // MARK: - Private

    private func saveCache(content: String, date: Date) {
        let url = Self.cacheFileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        defaults.set(date, forKey: lastFetchDateKey)
    }

    private func fileModificationDate(of url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }
}
