import Foundation

/// 应用状态与业务编排。
@MainActor
final class HostsStore: ObservableObject {

    enum ApplyState: Equatable {
        case notApplied   // /etc/hosts 中不存在 GitHub520 区块
        case upToDate     // 已写入且与最新内容一致
        case outdated     // 已写入但与最新内容不同
    }

    @Published private(set) var remoteContent: String = ""
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isBusy: Bool = false
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    @Published private(set) var applyState: ApplyState = .notApplied

    private let fetcher: HostsFetcher
    private let fileManager: HostsFileManager
    private let executor: PrivilegedExecutor

    init(fetcher: HostsFetcher = HostsFetcher(),
         fileManager: HostsFileManager = HostsFileManager(),
         executor: PrivilegedExecutor = PrivilegedExecutor()) {
        self.fetcher = fetcher
        self.fileManager = fileManager
        self.executor = executor
        loadFromCache()
        refreshStatus()
    }

    /// 从本地缓存恢复上次成功拉取的内容与时间。
    func loadFromCache() {
        guard let cached = fetcher.loadCache() else { return }
        remoteContent = cached.content
        lastUpdated = cached.date
    }

    /// 拉取最新内容。失败时保留现有缓存内容，仅提示错误。
    func refresh() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await fetcher.fetch()
            remoteContent = result.content
            lastUpdated = result.date
            errorMessage = nil
            refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 应用到 /etc/hosts 并刷新 DNS。
    func applyToSystem() async {
        guard !remoteContent.isEmpty else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            try await executor.applyHosts(block: remoteContent, refreshDNS: true)
            statusMessage = "已应用并刷新 DNS"
            errorMessage = nil
            refreshStatus()
        } catch let error as PrivilegeError {
            if case .cancelled = error {
                statusMessage = "已取消"
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 仅刷新 DNS。
    func flushDNS() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await executor.flushDNSOnly()
            statusMessage = "已刷新 DNS 缓存"
            errorMessage = nil
        } catch let error as PrivilegeError {
            if case .cancelled = error {
                statusMessage = "已取消"
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 根据 /etc/hosts 当前内容计算应用状态。
    func refreshStatus() {
        guard let current = fileManager.readSystemHosts(),
              HostsMerge.containsBlock(current) else {
            applyState = .notApplied
            return
        }

        if !remoteContent.isEmpty && fileManager.isUpToDate(latest: remoteContent) {
            applyState = .upToDate
        } else {
            applyState = .outdated
        }
    }
}
