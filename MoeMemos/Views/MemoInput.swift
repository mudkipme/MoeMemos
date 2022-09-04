//
//  MemoInput.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI

struct MemoInput: View {
    @State private var text = ""
    @State private var placeholderText = "Any thoughts…"
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack {
            ZStack {
                if text.isEmpty {
                    TextEditor(text: $placeholderText)
                        .foregroundColor(.secondary)
                        .disabled(true)
                        
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .opacity(text.isEmpty ? 0.25 : 1)
            }
            .padding()
            HStack {
                Button {
                    
                } label: {
                    Image(systemName: "number")
                }
                Button {
                    
                } label: {
                    Image(systemName: "camera")
                }
                Button {
                    
                } label: {
                    Image(systemName: "bold")
                }
                Spacer()
                Button {
                    
                } label: {
                    Label("Save", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding([.leading, .trailing, .bottom])
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                focused = true
            }
        }
    }
}

struct MemoInput_Previews: PreviewProvider {
    static var previews: some View {
        MemoInput()
    }
}
