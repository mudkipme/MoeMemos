//  TextView.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/6/12.
//

import SwiftUI

struct TextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: Range<String.Index>?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: CGRectZero)
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        return textView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if text != uiView.text {
            uiView.text = text
        }
        
        if let selection = selection, selection.upperBound <= text.endIndex {
            let range = NSRange(selection, in: text)
            if uiView.selectedRange != range {
                uiView.selectedRange = range
            }
        } else {
            if uiView.selectedRange.upperBound != 0 {
                uiView.selectedRange = NSRange()
            }
        }
    }
    
    @MainActor
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: TextView
        
        init(_ parent: TextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent._text.wrappedValue = textView.text
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent._selection.wrappedValue = Range(textView.selectedRange, in: textView.text)
        }
    }
}

struct TextView_Previews: PreviewProvider {
    @State static var text = "Hello world"
    @State static var selection: Range<String.Index>? = nil
    
    static var previews: some View {
        TextView(text: $text, selection: $selection)
    }
}
