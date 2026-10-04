import SwiftUI
import UIKit
import XCTest
@testable import MemoKit

@MainActor
final class TextViewTests: XCTestCase {
    func testUserFocusAndDismissalUpdateBinding() {
        var focused = false
        let editor = TextView(
            text: .constant("A memo"), selection: .constant(nil),
            isFocused: Binding(get: { focused }, set: { focused = $0 })
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()

        coordinator.textViewDidBeginEditing(textView)
        XCTAssertTrue(focused)
        coordinator.textViewDidEndEditing(textView)
        XCTAssertFalse(focused)
    }

    func testProgrammaticUpdatesDoNotOverwriteRequestedFocusOrText() {
        var focused = true
        var text = "Restored draft"
        let editor = TextView(
            text: Binding(get: { text }, set: { text = $0 }), selection: .constant(nil),
            isFocused: Binding(get: { focused }, set: { focused = $0 })
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.text = "Old text"
        coordinator.isUpdatingView = true

        coordinator.textViewDidEndEditing(textView)
        coordinator.textViewDidChange(textView)
        XCTAssertTrue(focused)
        XCTAssertEqual(text, "Restored draft")

        coordinator.isUpdatingView = false
        coordinator.textViewDidEndEditing(textView)
        XCTAssertFalse(focused)
    }
}
