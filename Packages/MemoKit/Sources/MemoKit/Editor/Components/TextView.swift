import SwiftUI

struct TextView: UIViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var text: String
    @Binding var selection: TextSelection?
    let isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.isEditable = isEnabled
        if textView.text != text {
            textView.text = text
        }

        if let selectionRange = nsRange(for: selection, in: text), textView.selectedRange != selectionRange {
            textView.selectedRange = selectionRange
        }

        if isEnabled, isFocused, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isEnabled, textView.isFirstResponder {
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
        let parent: TextView

        init(_ parent: TextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            updateSelection(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            updateSelection(from: textView)
        }

        private func updateSelection(from textView: UITextView) {
            guard let range = Range(textView.selectedRange, in: textView.text) else { return }
            parent.selection = TextSelection(range: range)
        }
    }
}
