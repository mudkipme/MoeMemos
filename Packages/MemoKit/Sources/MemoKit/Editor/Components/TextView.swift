import SwiftUI

struct TextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: Range<String.Index>?
    let shouldChangeText: ((_ range: Range<String.Index>, _ replacementText: String) -> Bool)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: CGRectZero)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: TextView

        init(_ parent: TextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let range = textView.selectedTextRange else { return }
            let startIndex = textView.offset(from: textView.beginningOfDocument, to: range.start)
            let endIndex = textView.offset(from: textView.beginningOfDocument, to: range.end)
            let text = parent.text
            let clampedStart = max(0, min(startIndex, text.count))
            let clampedEnd = max(clampedStart, min(endIndex, text.count))
            let start = text.index(text.startIndex, offsetBy: clampedStart)
            let end = text.index(text.startIndex, offsetBy: clampedEnd)
            parent.selection = start..<end
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let textRange = Range(range, in: parent.text)
            if let textRange = textRange, let shouldChangeText = parent.shouldChangeText {
                return shouldChangeText(textRange, text)
            }
            return true
        }
    }
}
