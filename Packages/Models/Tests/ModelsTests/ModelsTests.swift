import XCTest
@testable import Models

final class ModelsTests: XCTestCase {
    func testExtractsRegularTags() throws {
        let tags = MemoTagExtractor.extract(from: "hello #swift and #ios_dev")
        XCTAssertEqual(tags, ["swift", "ios_dev"])
    }

    func testExtractsHyphenatedTags() {
        let tags = MemoTagExtractor.extract(from: "#testa-testb #work-notes #2024_plans-q1")
        XCTAssertEqual(tags, ["testa-testb", "work-notes", "2024_plans-q1"])
    }

    func testExtractsHyphenatedHierarchicalTags() {
        let tags = MemoTagExtractor.extract(from: "#work-log/2024/q1-notes")
        XCTAssertEqual(tags, ["work-log/2024/q1-notes"])
    }

    func testHyphenatedTagsEndAtPunctuationAndExcludeCodeAndLinks() {
        let tags = MemoTagExtractor.extract(from: "#work-notes, #testa-testb. `#code-tag` [#link-tag](https://example.com) https://example.com/#url-tag")
        XCTAssertEqual(tags, ["work-notes", "testa-testb"])
    }

    func testDoesNotExtractURLFragmentAsTag() throws {
        let tags = MemoTagExtractor.extract(from: "hello http://example.com/#heading")
        XCTAssertTrue(tags.isEmpty)
    }

    func testExtractsTagAndIgnoresURLFragmentInSameLine() throws {
        let tags = MemoTagExtractor.extract(from: "see http://example.com/#heading and #realTag")
        XCTAssertEqual(tags, ["realTag"])
    }
}
