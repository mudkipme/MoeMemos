import SwiftUI

/// Applies programmatic edits through `UITextView` so they can be undone.
@MainActor
final class TextViewController {
    weak var textView: UITextView?

    enum EditResult: Equatable { case applied, unavailable, ignored }

    var text: String? { textView?.text }
    var selectedRange: NSRange? { textView?.selectedRange }
    var isComposing: Bool { textView?.markedTextRange != nil }

    func commitComposition() {
        guard let textView else { return }
        textView.unmarkText()
        textView.delegate?.textViewDidChange?(textView)
        textView.delegate?.textViewDidChangeSelection?(textView)
    }

    /// Only an unavailable view permits a binding fallback. Composition and stale
    /// selections must never turn into a direct replacement of the editor text.
    @discardableResult
    func apply(_ edit: MarkdownEdit) -> EditResult {
        guard let textView else { return .unavailable }
        guard !isComposing, textView.isEditable, edit.isValid(in: textView.text),
              let start = textView.position(from: textView.beginningOfDocument, offset: edit.range.location),
              let end = textView.position(from: start, offset: edit.range.length),
              let range = textView.textRange(from: start, to: end) else { return .ignored }
        textView.replace(range, withText: edit.replacement)
        textView.selectedRange = edit.selection
        // `replace(_:withText:)` doesn't reliably notify the delegate, so sync the bindings here.
        textView.delegate?.textViewDidChange?(textView)
        textView.delegate?.textViewDidChangeSelection?(textView)
        return .applied
    }
}

private final class MarkdownTextView: UITextView {
    var onFormat: ((MarkdownFormat) -> Void)?

    override var keyCommands: [UIKeyCommand]? {
        let commands: [(String, MarkdownFormat)] = [("b", .bold), ("i", .italic), ("k", .link)]
        return commands.map { input, format in
            let command = UIKeyCommand(
                title: format.title,
                action: #selector(performFormatKeyCommand(_:)),
                input: input,
                modifierFlags: .command,
                propertyList: input
            )
            command.wantsPriorityOverSystemBehavior = true
            return command
        } + (super.keyCommands ?? [])
    }

    @objc private func performFormatKeyCommand(_ command: UIKeyCommand) {
        guard isEditable, markedTextRange == nil else { return }
        switch command.propertyList as? String {
        case "b": onFormat?(.bold)
        case "i": onFormat?(.italic)
        case "k": onFormat?(.link)
        default: break
        }
    }
}

struct TextView: UIViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var text: String
    @Binding var selection: TextSelection?
    @Binding var isFocused: Bool
    var controller: TextViewController?
    var onFormat: ((MarkdownFormat) -> Void)?
    var onCompositionChange: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = MarkdownTextView(frame: .zero)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.keyboardDismissMode = .interactive
        controller?.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Delegates must use the latest bindings and avoid publishing state while
        // SwiftUI applies programmatic text, selection, or focus changes.
        context.coordinator.parent = self
        context.coordinator.updateView(textView, isEnabled: isEnabled)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func nsRange(for selection: TextSelection?, in text: String) -> NSRange? {
        guard let selection else { return nil }
        switch selection.indices {
        case .selection(let range):
            guard let lower = String.Index(range.lowerBound, within: text),
                  let upper = String.Index(range.upperBound, within: text) else { return nil }
            return NSRange(lower..<upper, in: text)
        case .multiSelection:
            return nil
        @unknown default:
            return nil
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView
        var isUpdatingView = false
        private var isComposing = false

        init(_ parent: TextView) {
            self.parent = parent
        }

        func updateView(_ textView: UITextView, isEnabled: Bool) {
            parent.controller?.textView = textView
            (textView as? MarkdownTextView)?.onFormat = parent.onFormat
            isUpdatingView = true
            defer { isUpdatingView = false }
            let hadMarkedText = textView.markedTextRange != nil
            textView.isEditable = isEnabled
            // Marked text and its selection belong to the input method until committed.
            if !hadMarkedText, textView.markedTextRange == nil {
                // Canonically equal NFC/NFD strings can have different UTF-16
                // lengths. UIKit text must match the selection's actual encoding.
                if !textView.text.utf16.elementsEqual(parent.text.utf16) {
                    textView.text = parent.text
                }
                if let selectionRange = parent.nsRange(for: parent.selection, in: parent.text), textView.selectedRange != selectionRange {
                    textView.selectedRange = selectionRange
                }
            }

            if isEnabled, parent.isFocused, !textView.isFirstResponder {
                textView.becomeFirstResponder()
            } else if (!isEnabled || !parent.isFocused), textView.isFirstResponder {
                textView.resignFirstResponder()
            }
            if hadMarkedText, textView.markedTextRange == nil {
                // Resigning can commit a candidate synchronously. Publish its final
                // text after SwiftUI's update rather than from inside updateUIView.
                Task { @MainActor [weak self, weak textView] in
                    guard let self, let textView else { return }
                    self.textViewDidChange(textView)
                }
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            updateComposition(from: textView)
            parent.text = textView.text
            updateSelection(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            updateComposition(from: textView)
            updateSelection(from: textView)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n", textView.markedTextRange == nil,
                  textView.undoManager?.isUndoing != true,
                  textView.undoManager?.isRedoing != true,
                  let edit = MemoTextEditing.newlineEdit(in: textView.text, selection: range) else { return true }
            let controller = TextViewController()
            controller.textView = textView
            return controller.apply(edit) != .applied
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            updateComposition(from: textView)
            parent.text = textView.text
            updateSelection(from: textView)
            parent.isFocused = false
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard range.length > 0, textView.isEditable, textView.markedTextRange == nil,
                  let onFormat = parent.onFormat else { return nil }
            let formats: [MarkdownFormat] = [.bold, .italic, .strikethrough, .code, .link]
            let actions = formats.map { format in
                UIAction(title: format.title, image: UIImage(systemName: format.systemImage)) { _ in
                    onFormat(format)
                }
            }
            let formatMenu = UIMenu(
                title: NSLocalizedString("input.format", comment: "Format"),
                image: UIImage(systemName: "textformat"),
                children: actions
            )
            return UIMenu(children: suggestedActions + [formatMenu])
        }

        private func updateSelection(from textView: UITextView) {
            guard let range = EditorTextRange.characters(textView.selectedRange, in: textView.text) else { return }
            parent.selection = TextSelection(range: range)
        }

        private func updateComposition(from textView: UITextView) {
            let composing = textView.markedTextRange != nil
            guard composing != isComposing else { return }
            isComposing = composing
            parent.onCompositionChange?(composing)
        }
    }
}
