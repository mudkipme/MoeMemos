import SwiftUI

/// Applies programmatic edits through `UITextView` so they can be undone.
@MainActor
final class TextViewController {
    weak var textView: UITextView?

    var selectedRange: NSRange? { textView?.selectedRange }

    /// Returns `false` when no text view is attached; callers then edit the binding directly.
    @discardableResult
    func apply(_ edit: MarkdownEdit) -> Bool {
        guard let textView,
              let start = textView.position(from: textView.beginningOfDocument, offset: edit.range.location),
              let end = textView.position(from: start, offset: edit.range.length),
              let range = textView.textRange(from: start, to: end) else { return false }
        textView.replace(range, withText: edit.replacement)
        textView.selectedRange = edit.selection
        // `replace(_:withText:)` doesn't reliably notify the delegate, so sync the bindings here.
        textView.delegate?.textViewDidChange?(textView)
        textView.delegate?.textViewDidChangeSelection?(textView)
        return true
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
        controller?.textView = textView
        (textView as? MarkdownTextView)?.onFormat = onFormat
        context.coordinator.isUpdatingView = true
        defer { context.coordinator.isUpdatingView = false }
        textView.isEditable = isEnabled
        if textView.text != text {
            textView.text = text
        }

        if let selectionRange = nsRange(for: selection, in: text), textView.selectedRange != selectionRange {
            textView.selectedRange = selectionRange
        }

        if isEnabled, isFocused, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if (!isEnabled || !isFocused), textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func nsRange(for selection: TextSelection?, in text: String) -> NSRange? {
        guard let selection else { return nil }
        switch selection.indices {
        case .selection(let range):
            let lower = range.lowerBound.utf16Offset(in: text)
            let upper = range.upperBound.utf16Offset(in: text)
            return NSRange(location: lower, length: upper - lower)
        case .multiSelection:
            return nil
        @unknown default:
            return nil
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView
        var isUpdatingView = false

        init(_ parent: TextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            parent.text = textView.text
            updateSelection(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            updateSelection(from: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            parent.isFocused = false
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard range.length > 0, textView.isEditable, let onFormat = parent.onFormat else { return nil }
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
            guard let range = Range(textView.selectedRange, in: textView.text) else { return }
            parent.selection = TextSelection(range: range)
        }
    }
}
