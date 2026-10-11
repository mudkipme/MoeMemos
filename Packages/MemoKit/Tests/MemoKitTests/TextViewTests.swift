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

    func testControllerEditsThroughTextViewAndSyncsBindings() {
        var text = "hello"
        var selection: TextSelection?
        let controller = TextViewController()
        let editor = TextView(
            text: Binding(get: { text }, set: { text = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }),
            isFocused: .constant(false),
            controller: controller
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.text = text
        textView.delegate = coordinator
        controller.textView = textView

        let edit = MarkdownFormatter.edit(for: .bold, in: text, selection: NSRange(location: 0, length: 5))
        XCTAssertTrue(controller.apply(edit))
        XCTAssertEqual(textView.text, "**hello**")
        XCTAssertEqual(text, "**hello**")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 5))
        XCTAssertNotNil(selection)
    }

    func testControllerWithoutTextViewReportsFailure() {
        XCTAssertFalse(TextViewController().apply(MarkdownEdit(range: NSRange(), replacement: "x", selection: NSRange())))
    }
}
