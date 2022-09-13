//
//  MemoInput.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI

struct MemoInput: View {
    let memo: Memo?
    @EnvironmentObject private var memosViewModel: MemosViewModel
    
    @State private var text = ""
    @State private var placeholderText = "Any thoughts…"
    @AppStorage("draft") private var draft = ""
    
    @FocusState private var focused: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var showingPhotoPicker = false
    @State private var submitError: Error?
    @State private var showingErrorToast = false
    
    @ViewBuilder
    private func toolbar() -> some View {
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
            showingPhotoPicker = true
        } label: {
            Image(systemName: "photo.on.rectangle")
        }
        Spacer()
    }
    
    @ViewBuilder
    private func editor() -> some View {
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
    }

    var body: some View {
        NavigationView {
            editor()
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
                .sheet(isPresented: $showingPhotoPicker) {
                    PhotoPicker { images in
                        Task {
                            do {
                                try await upload(images: images)
                                submitError = nil
                            } catch {
                                submitError = error
                                showingErrorToast = true
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(memo == nil ? "Compose" : "Edit Memo")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Close")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
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
                    }
                    
                    ToolbarItemGroup(placement: .keyboard) {
                        toolbar()
                    }
                }
        }
        
    }
    
    func upload(images: [UIImage]) async throws {
        for image in images {
            let resource = try await memosViewModel.upload(image: image)
            text += "![](/o/r/\(resource.id)/\(resource.filename))"
        }
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
