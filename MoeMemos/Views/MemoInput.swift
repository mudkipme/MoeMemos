//
//  MemoInput.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI

struct MemoInput: View {
    let memo: Memo?
    @State private var text = ""
    @State private var placeholderText = "Any thoughts…"
    @FocusState private var focused: Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @AppStorage("draft") private var draft = ""
    @State private var submitError: Error?
    @State private var showingErrorToast = false

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
                Spacer()
                Button {
                    Task {
                        do {
                            try await saveMemo()
                            submitError = nil
                        } catch {
                            submitError = error
                            showingErrorToast = true
                        }
                    }
                } label: {
                    Label("Save", systemImage: "paperplane")
                }
                .disabled(text.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding([.leading, .trailing, .bottom])
        }
        .onAppear {
            if let memo = memo {
                text = memo.content
            } else {
                text = draft
            }
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
            if memo == nil {
                draft = text
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if memo == nil {
                draft = text
            }
        }
        .toast(isPresenting: $showingErrorToast, alertType: .systemImage("xmark.circle", submitError?.localizedDescription))
    }
    
    func saveMemo() async throws {
        if let memo = memo {
            try await memosViewModel.editMemo(id: memo.id, content: text)
        } else {
            try await memosViewModel.createMemo(content: text)
            draft = ""
        }
        text = ""
        dismiss()
    }
}

struct MemoInput_Previews: PreviewProvider {
    static var previews: some View {
        MemoInput(memo: nil)
            .environmentObject(MemosViewModel())
    }
}
