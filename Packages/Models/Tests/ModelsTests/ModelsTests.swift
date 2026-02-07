import XCTest
@testable import Models

final class ModelsTests: XCTestCase {
    func testExtractsRegularTags() throws {
        let tags = MemoTagExtractor.extract(from: "hello #swift and #ios_dev")
        XCTAssertEqual(tags, ["swift", "ios_dev"])
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
