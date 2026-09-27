import XCTest
@testable import GitHubHosts

/// 针对「应用区块时覆盖整个 /etc/hosts」这类数据丢失问题的回归测试。
///
/// 关键点：`PrivilegedExecutor.applyHosts(block:)` 写入的必须是**合并后的完整文件**，
/// 而不是区块本身；原有内容（localhost、用户自己的记录）必须原样保留。
final class HostsApplyTests: XCTestCase {

    private let block = """
    # GitHub520 Host Start
    1.1.1.1 github.com
    2.2.2.2 raw.githubusercontent.com
    # GitHub520 Host End
    """

    private var tempDir: URL!
    private var hostsPath: String!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("HostsApplyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        hostsPath = tempDir.appendingPathComponent("hosts").path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeHosts(_ text: String) throws {
        try text.write(toFile: hostsPath, atomically: true, encoding: .utf8)
    }

    private func countBlocks(_ text: String) -> Int {
        text.components(separatedBy: "\n").filter { HostsMerge.isStartMarker($0) }.count
    }

    // MARK: - 回归：绝不能整文件覆盖

    func testMergedSystemHostsPreservesExistingEntries() throws {
        try writeHosts("""
        127.0.0.1     localhost
        255.255.255.255 broadcasthost
        ::1           localhost

        """)

        let merged = try PrivilegedExecutor()
            .mergedSystemHosts(block: block, fileManager: HostsFileManager(hostsPath: hostsPath))

        XCTAssertTrue(merged.contains("127.0.0.1     localhost"), "原有 localhost 必须保留")
        XCTAssertTrue(merged.contains("255.255.255.255 broadcasthost"), "原有 broadcasthost 必须保留")
        XCTAssertTrue(merged.contains("::1           localhost"), "原有 IPv6 localhost 必须保留")
        XCTAssertTrue(merged.contains("1.1.1.1 github.com"), "GitHub520 区块应写入")
        XCTAssertEqual(countBlocks(merged), 1)
    }

    // MARK: - 回归：区块之后的用户记录不得被删

    func testMergedSystemHostsPreservesEntriesAfterExistingBlock() throws {
        try writeHosts("""
        127.0.0.1 localhost

        # GitHub520 Host Start
        9.9.9.9 old.example.com
        # GitHub520 Host End

        # 用户自己加的
        10.0.0.1 my.local
        """)

        let merged = try PrivilegedExecutor()
            .mergedSystemHosts(block: block, fileManager: HostsFileManager(hostsPath: hostsPath))

        XCTAssertTrue(merged.contains("127.0.0.1 localhost"))
        XCTAssertTrue(merged.contains("10.0.0.1 my.local"), "旧区块之后的用户记录必须保留")
        XCTAssertTrue(merged.contains("# 用户自己加的"))
        XCTAssertFalse(merged.contains("9.9.9.9"), "旧区块应被替换")
        XCTAssertEqual(countBlocks(merged), 1)
    }

    // MARK: - 幂等

    func testMergeIsIdempotentOnRealFile() throws {
        try writeHosts("127.0.0.1 localhost\n")
        let executor = PrivilegedExecutor()
        let fileManager = HostsFileManager(hostsPath: hostsPath)

        let once = try executor.mergedSystemHosts(block: block, fileManager: fileManager)
        try writeHosts(once)
        let twice = try executor.mergedSystemHosts(block: block, fileManager: fileManager)

        XCTAssertEqual(once, twice, "重复应用必须完全幂等")
        XCTAssertEqual(countBlocks(twice), 1)
    }

    // MARK: - 空文件 / 读取失败

    func testMergedSystemHostsOnEmptyFile() throws {
        try writeHosts("")
        let merged = try PrivilegedExecutor()
            .mergedSystemHosts(block: block, fileManager: HostsFileManager(hostsPath: hostsPath))

        XCTAssertEqual(countBlocks(merged), 1)
        XCTAssertEqual(merged, block + "\n")
    }

    func testMergedSystemHostsThrowsWhenFileMissing() {
        let missing = tempDir.appendingPathComponent("not-exists").path
        XCTAssertThrowsError(
            try PrivilegedExecutor()
                .mergedSystemHosts(block: block, fileManager: HostsFileManager(hostsPath: missing))
        )
    }

    // MARK: - 应用状态判定只看区块

    func testIsUpToDateComparesOnlyTheBlock() throws {
        try writeHosts("""
        127.0.0.1 localhost

        \(block)

        # 用户后来自己加了一行，不应影响「已是最新」判断
        10.0.0.1 my.local
        """)

        let fileManager = HostsFileManager(hostsPath: hostsPath)
        XCTAssertTrue(fileManager.isUpToDate(latest: block),
                      "判定是否最新应只比较 Start~End 区块，不受区块外内容影响")
        XCTAssertFalse(fileManager.isUpToDate(latest: block + "\n1.3.3.3 new.example.com"))
    }
}
