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
            parent._text.wrappedValue = textView.text
            parent._selection.wrappedValue = Range(textView.selectedRange, in: textView.text)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent._text.wrappedValue = textView.text
            parent._selection.wrappedValue = Range(textView.selectedRange, in: textView.text)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if let shouldChangeText = parent.shouldChangeText, let textRange = Range(range, in: textView.text) {
                return shouldChangeText(textRange, text)
            }
            return true
        }
    }
}
