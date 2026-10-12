import XCTest
@testable import MemoKit

@MainActor
final class MemoAttachmentImporterTests: XCTestCase {
    private enum Failure: Error { case unreadable }

    func testFailureDoesNotStopBatchAndRetryOnlyRepeatsFailedItem() async {
        let importer = MemoAttachmentImporter()
        var attempts = 0
        var successes = 0
        let failed = MemoAttachmentImporter.Input(name: "first") {
            attempts += 1
            if attempts == 1 { throw Failure.unreadable }
        }
        let successful = MemoAttachmentImporter.Input(name: "second") { successes += 1 }

        await importer.importItems([failed, successful])

        XCTAssertEqual(successes, 1)
        XCTAssertEqual(importer.items.map(\.id), [failed.id])
        if case .failed = importer.items.first?.state {} else { XCTFail("Expected retryable failure") }
        XCTAssertFalse(importer.isImporting)

        await importer.retry(id: failed.id)

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(successes, 1)
        XCTAssertFalse(importer.hasUnfinishedImports)
    }

    func testInputsQueuedDuringImportRunSequentially() async {
        let importer = MemoAttachmentImporter()
        var events: [String] = []
        let second = MemoAttachmentImporter.Input(name: "second") { events.append("second") }
        let first = MemoAttachmentImporter.Input(name: "first") {
            events.append("first started")
            await importer.importItems([second])
            events.append("first finished")
        }

        await importer.importItems([first])

        XCTAssertEqual(events, ["first started", "first finished", "second"])
        XCTAssertTrue(importer.items.isEmpty)
    }

    func testRemovingFailureDoesNotRepeatSuccessfulImports() async {
        let importer = MemoAttachmentImporter()
        let input = MemoAttachmentImporter.Input(name: "failed") { throw Failure.unreadable }
        await importer.importItems([input])
        importer.remove(id: input.id)
        XCTAssertFalse(importer.hasUnfinishedImports)
        await importer.retry(id: input.id)
        XCTAssertTrue(importer.items.isEmpty)
    }
}
