import XCTest
@testable import GitHubHosts

final class HostsMergeTests: XCTestCase {

    // MARK: - Fixtures

    private let block = """
    # GitHub520 Host Start
    1.1.1.1 github.com
    2.2.2.2 raw.githubusercontent.com
    # GitHub520 Host End
    """

    private let oldBlock = """
    # GitHub520 Host Start
    9.9.9.9 old.example.com
    # GitHub520 Host End
    """

    private func countBlocks(_ text: String) -> Int {
        text.components(separatedBy: "\n")
            .filter { HostsMerge.isStartMarker($0) }
            .count
    }

    // MARK: - Tests

    func testFirstInsertBeforeAnyBlock() {
        let original = "127.0.0.1 localhost\n255.255.255.255 broadcasthost\n"
        let result = HostsMerge.merge(original: original, block: block)

        XCTAssertTrue(result.contains("127.0.0.1 localhost"))
        XCTAssertTrue(result.contains("255.255.255.255 broadcasthost"))
        XCTAssertTrue(result.contains("1.1.1.1 github.com"))
        XCTAssertEqual(countBlocks(result), 1)
        XCTAssertTrue(result.hasSuffix("# GitHub520 Host End\n"))
    }

    func testReplaceExistingBlock() {
        let original = "127.0.0.1 localhost\n\n\(oldBlock)\n"
        let result = HostsMerge.merge(original: original, block: block)

        XCTAssertFalse(result.contains("9.9.9.9"))
        XCTAssertFalse(result.contains("old.example.com"))
        XCTAssertTrue(result.contains("1.1.1.1 github.com"))
        XCTAssertTrue(result.contains("127.0.0.1 localhost"))
        XCTAssertEqual(countBlocks(result), 1)
    }

    func testMultipleStaleBlocksAreRemoved() {
        let second = """
        # GitHub520 Host Start
        8.8.8.8 another.example.com
        # GitHub520 Host End
        """
        let original = "\(oldBlock)\n\n127.0.0.1 localhost\n\n\(second)\n"
        let result = HostsMerge.merge(original: original, block: block)

        XCTAssertEqual(countBlocks(result), 1)
        XCTAssertFalse(result.contains("9.9.9.9"))
        XCTAssertFalse(result.contains("8.8.8.8"))
        XCTAssertTrue(result.contains("127.0.0.1 localhost"))
    }

    func testEmptyFile() {
        let result = HostsMerge.merge(original: "", block: block)
        XCTAssertEqual(result, block + "\n")
        XCTAssertEqual(countBlocks(result), 1)
    }

    func testMissingTrailingNewline() {
        let original = "127.0.0.1 localhost"
        let result = HostsMerge.merge(original: original, block: block)

        XCTAssertTrue(result.contains("127.0.0.1 localhost\n\n# GitHub520 Host Start"))
        XCTAssertEqual(countBlocks(result), 1)
        XCTAssertFalse(result.contains("\n\n\n"), "不应产生多余空行")
        XCTAssertTrue(result.hasSuffix("# GitHub520 Host End\n"))
    }

    func testIdempotency() {
        let first = HostsMerge.merge(original: "127.0.0.1 localhost\n", block: block)
        let second = HostsMerge.merge(original: first, block: block)

        XCTAssertEqual(countBlocks(first), 1)
        XCTAssertEqual(countBlocks(second), 1)
        XCTAssertEqual(first, second, "重复合并应完全幂等")
    }

    func testIdempotencyWithExistingBlock() {
        let original = "127.0.0.1 localhost\n\n\(oldBlock)\n"
        let first = HostsMerge.merge(original: original, block: block)
        let second = HostsMerge.merge(original: first, block: block)
        XCTAssertEqual(first, second)
    }

    func testUnrelatedLinesPreserved() {
        let original = "# comment line\n127.0.0.1 localhost\n::1 localhost\n"
        let result = HostsMerge.merge(original: original, block: block)

        for line in ["# comment line", "127.0.0.1 localhost", "::1 localhost"] {
            XCTAssertTrue(result.contains(line), "应保留无关行：\(line)")
        }
    }

    func testStripExistingBlock() {
        let original = "127.0.0.1 localhost\n\n\(oldBlock)\n"
        let stripped = HostsMerge.stripExistingBlock(from: original)

        XCTAssertFalse(stripped.contains(HostsMerge.startMarker))
        XCTAssertFalse(stripped.contains(HostsMerge.endMarker))
        XCTAssertTrue(stripped.contains("127.0.0.1 localhost"))
    }

    func testContainsBlock() {
        XCTAssertTrue(HostsMerge.containsBlock(block))
        XCTAssertTrue(HostsMerge.containsBlock("127.0.0.1 localhost\n\(block)\n"))
        XCTAssertFalse(HostsMerge.containsBlock("127.0.0.1 localhost"))
        XCTAssertFalse(HostsMerge.containsBlock(""))
    }

    func testNormalizeIgnoresLineEndingsAndTrailingWhitespace() {
        let a = "# GitHub520 Host Start\r\n1.1.1.1 github.com\r\n# GitHub520 Host End\r\n"
        let b = "# GitHub520 Host Start\n1.1.1.1 github.com\n# GitHub520 Host End"
        XCTAssertEqual(HostsMerge.normalize(a), HostsMerge.normalize(b))
    }

    func testExtractBlock() {
        let text = "127.0.0.1 localhost\n\(oldBlock)\n# tail\n"
        let extracted = HostsMerge.extractBlock(from: text)
        XCTAssertEqual(extracted, oldBlock)
        XCTAssertNil(HostsMerge.extractBlock(from: "127.0.0.1 localhost"))
    }
}
