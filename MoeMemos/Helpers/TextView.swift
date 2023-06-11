//
//  TextView.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/6/12.
//

import SwiftUI

struct TextView: UIViewRepresentable {
    @Binding var text: String
    
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
        uiView.text = text
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: TextView
        
        init(_ parent: TextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

struct TextView_Previews: PreviewProvider {
    @State static var text = "Hello world"
    
    static var previews: some View {
        TextView(text: $text)
    }
}
