import SwiftUI
import UIKit
import XCTest
@testable import MemoKit

@MainActor
final class MemoEditorToolbarTests: XCTestCase {
    func testControlsFitNarrowContainersWithoutConsumingEditorHeight() {
        let toolbar = MemoEditorToolbar(
            tags: [],
            onInsertTag: { _ in },
            onToggleTodo: {},
            onFormat: { _ in },
            onPickJournalingSuggestion: {},
            supportsJournalingSuggestions: true,
            onPickPhotos: {},
            onPickCamera: {},
            supportsDocumentScanning: true,
            onScanDocument: {},
            onPickFiles: {},
            supportsLocations: true,
            onPickLocation: {}
        )

        for width: CGFloat in [180, 220, 280, 340, 600] {
            let host = UIHostingController(rootView: toolbar)
            let size = host.sizeThatFits(in: CGSize(width: width, height: 500))
            XCTAssertLessThanOrEqual(size.width, width + 1, "Toolbar overflow at width \(width)")
            XCTAssertGreaterThanOrEqual(size.height, 44, "Controls must retain their tap target height")
            XCTAssertLessThanOrEqual(size.height, 80, "Toolbar must leave room for writing at width \(width)")
        }
    }
}
