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
        XCTAssertEqual(controller.apply(edit), .applied)
        XCTAssertEqual(textView.text, "**hello**")
        XCTAssertEqual(text, "**hello**")
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 5))
        XCTAssertNotNil(selection)
    }

    func testControllerWithoutTextViewReportsFailure() {
        XCTAssertEqual(TextViewController().apply(MarkdownEdit(range: NSRange(), replacement: "x", selection: NSRange())), .unavailable)
    }
    func testControllerDoesNotReplaceMarkedTextOrFallBackToBinding() throws {
        let textView = UITextView()
        textView.text = "hello "
        textView.selectedRange = NSRange(location: 6, length: 0)
        textView.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(textView.markedTextRange)
        let controller = TextViewController()
        controller.textView = textView
        let original = textView.text!
        let edit = MarkdownFormatter.edit(for: .bold, in: original, selection: textView.selectedRange)

        XCTAssertEqual(controller.apply(edit), .ignored)
        XCTAssertEqual(textView.text, original)
        XCTAssertNotNil(textView.markedTextRange)
    }

    func testViewUpdatePreservesMarkedTextAndItsSelection() {
        let boundText = "Restored draft"
        let editor = TextView(text: .constant(boundText), selection: .constant(nil), isFocused: .constant(false))
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.setMarkedText("zhong", selectedRange: NSRange(location: 3, length: 0))
        let original = textView.text
        let selection = textView.selectedRange
        XCTAssertNotNil(textView.markedTextRange)

        coordinator.updateView(textView, isEnabled: true)

        XCTAssertEqual(textView.text, original)
        XCTAssertEqual(textView.selectedRange, selection)
        XCTAssertNotNil(textView.markedTextRange)
    }

    func testCompositionChangesAreReportedAndFinalTextIsCommitted() {
        var text = ""
        var composing = false
        let controller = TextViewController()
        let editor = TextView(
            text: Binding(get: { text }, set: { text = $0 }), selection: .constant(nil),
            isFocused: .constant(false), controller: controller,
            onCompositionChange: { composing = $0 }
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.delegate = coordinator
        controller.textView = textView
        textView.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0))
        coordinator.textViewDidChange(textView)
        XCTAssertTrue(composing)

        controller.commitComposition()

        XCTAssertFalse(composing)
        XCTAssertNil(textView.markedTextRange)
        XCTAssertEqual(text, "中文")
    }

    func testReturnContinuesListAndSynchronizesBindings() {
        var text = "- [x] done"
        let editor = TextView(
            text: Binding(get: { text }, set: { text = $0 }), selection: .constant(nil), isFocused: .constant(false)
        )
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.text = text
        textView.selectedRange = NSRange(location: text.utf16.count, length: 0)
        textView.delegate = coordinator

        XCTAssertFalse(coordinator.textView(textView, shouldChangeTextIn: textView.selectedRange, replacementText: "\n"))
        XCTAssertEqual(text, "- [x] done\n- [ ] ")
        XCTAssertEqual(textView.text, text)
        XCTAssertEqual(textView.selectedRange, NSRange(location: text.utf16.count, length: 0))
    }

    func testPasteAndComposingReturnDoNotTriggerContinuation() {
        let editor = TextView(text: .constant(""), selection: .constant(nil), isFocused: .constant(false))
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.text = "- item"
        textView.selectedRange = NSRange(location: 6, length: 0)
        XCTAssertTrue(coordinator.textView(textView, shouldChangeTextIn: textView.selectedRange, replacementText: "\n- pasted"))

        textView.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertTrue(coordinator.textView(textView, shouldChangeTextIn: textView.selectedRange, replacementText: "\n"))
    }

    func testControllerRejectsInvalidRangesAndDisabledEditing() {
        let controller = TextViewController()
        let textView = UITextView()
        textView.text = "hello"
        controller.textView = textView
        XCTAssertEqual(controller.apply(MarkdownEdit(range: NSRange(location: 99, length: 0), replacement: "x", selection: NSRange())), .ignored)
        textView.isEditable = false
        XCTAssertEqual(controller.apply(MarkdownEdit(range: NSRange(), replacement: "x", selection: NSRange())), .ignored)
        XCTAssertEqual(textView.text, "hello")
    }

    func testListContinuationCanBeUndoneInOneOperation() throws {
        let editor = TextView(text: .constant("- item"), selection: .constant(nil), isFocused: .constant(false))
        let coordinator = editor.makeCoordinator()
        let textView = UITextView()
        textView.text = "- item"
        textView.delegate = coordinator
        textView.selectedRange = NSRange(location: 6, length: 0)
        let undoManager = try XCTUnwrap(textView.undoManager)
        undoManager.beginUndoGrouping()
        XCTAssertFalse(coordinator.textView(textView, shouldChangeTextIn: textView.selectedRange, replacementText: "\n"))
        undoManager.endUndoGrouping()
        XCTAssertEqual(textView.text, "- item\n- ")

        undoManager.undo()

        XCTAssertEqual(textView.text, "- item")
    }

    func testViewUpdateSynchronizesExactNFCAndNFDRepresentationBeforeSelection() {
        for (boundText, initialText) in [("cafe\u{301}", "caf\u{e9}"), ("caf\u{e9}", "cafe\u{301}")] {
            XCTAssertEqual(boundText, initialText) // Swift equality is canonical.
            XCTAssertNotEqual(Array(boundText.utf16), Array(initialText.utf16))
            let editor = TextView(
                text: .constant(boundText), selection: .constant(TextSelection(insertionPoint: boundText.endIndex)),
                isFocused: .constant(false)
            )
            let textView = UITextView()
            textView.text = initialText

            editor.makeCoordinator().updateView(textView, isEnabled: true)

            XCTAssertEqual(Array(textView.text.utf16), Array(boundText.utf16))
            XCTAssertEqual(textView.selectedRange, NSRange(location: boundText.utf16.count, length: 0))
        }
    }

    func testControllerRejectsEditsInsideEmojiAndCombiningSequences() {
        let controller = TextViewController()
        let textView = UITextView()
        controller.textView = textView
        for text in ["👨‍👩‍👧‍👦", "👍🏽", "🇯🇵", "1️⃣", "e\u{301}"] {
            textView.text = text
            for offset in 1..<text.utf16.count {
                let edit = MarkdownEdit(range: NSRange(location: offset, length: 0), replacement: "x", selection: NSRange())
                XCTAssertEqual(controller.apply(edit), .ignored, "\(text) at UTF-16 offset \(offset)")
                XCTAssertEqual(Array(textView.text.utf16), Array(text.utf16))
            }
        }
    }

}
