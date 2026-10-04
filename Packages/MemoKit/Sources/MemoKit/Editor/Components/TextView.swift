import SwiftUI

struct TextView: UIViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var text: String
    @Binding var selection: TextSelection?
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.keyboardDismissMode = .interactive
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Delegates must use the latest bindings and avoid publishing state while
        // SwiftUI applies programmatic text, selection, or focus changes.
        context.coordinator.parent = self
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

        private func updateSelection(from textView: UITextView) {
            guard let range = Range(textView.selectedRange, in: textView.text) else { return }
            parent.selection = TextSelection(range: range)
        }
    }
}
