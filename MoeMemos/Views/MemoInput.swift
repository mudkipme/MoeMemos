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
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @AppStorage("draft") private var draft = ""

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
                if !memosViewModel.tags.isEmpty {
                    Menu {
                        ForEach(memosViewModel.tags) { tag in
                            Button(tag.name) {
                                text += "#\(tag.name) "
                            }
                        }
                    } label: {
                        Image(systemName: "number")
                    }
                } else {
                    Button {
                        text += "#"
                    } label: {
                        Image(systemName: "number")
                    }
                }
                
                Button {
                    
                } label: {
                    Image(systemName: "camera")
                }
                Spacer()
                Button {
                    Task {
                        try await createMemo()
                    }
                } label: {
                    Label("Save", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding([.leading, .trailing, .bottom])
        }
        .onAppear {
            text = draft
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                focused = true
            }
        }
        .task {
            do {
                try await memosViewModel.loadTags()
            } catch {
                print(error)
            }
        }
        .onDisappear {
            draft = text
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            draft = text
        }
    }
    
    func createMemo() async throws {
        try await memosViewModel.createMemo(content: text)
        text = ""
        draft = ""
        dismiss()
    }
}

struct MemoInput_Previews: PreviewProvider {
    static var previews: some View {
        MemoInput()
            .environmentObject(MemosViewModel())
    }
}
