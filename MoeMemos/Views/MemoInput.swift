//
//  MemoInput.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI
import PhotosUI

struct MemoInput: View {
    let memo: Memo?
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @StateObject private var viewModel = MemoInputViewModel()
    
    @State private var text = ""
    @State private var placeholderText = "Any thoughts…"
    @AppStorage("draft") private var draft = ""
    
    @FocusState private var focused: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var showingPhotoPicker = false
    @State private var showingImagePicker = false
    @State private var submitError: Error?
    @State private var showingErrorToast = false
    
    @ViewBuilder
    private func toolbar() -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center) {
                if !memosViewModel.tags.isEmpty {
                    ZStack {
                        Menu {
                            ForEach(memosViewModel.tags) { tag in
                                Button(tag.name) {
                                    text += "#\(tag.name) "
                                }
                            }
                        } label: {
                            // On iOS 16, the position of menu label is unstable after keyboard change,
                            // So we use a transparent menu label here
                            Color.clear.frame(width: 15)
                        }
                        Button {
                            // Do nothing, pass through to the menu
                        } label: {
                            Image(systemName: "number")
                        }
                        .allowsHitTesting(false)
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
                
                Button {
                    showingImagePicker = true
                } label: {
                    Image(systemName: "camera")
                }
                
                Spacer()
            }
            .frame(height: 20)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    @ViewBuilder
    private func editor() -> some View {
        ZStack(alignment: .bottom) {
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
                .padding([.leading, .trailing])
                
                MemoInputResourceView(viewModel: viewModel)
            }
            .padding(.bottom, 40)
            toolbar()
        }
        
        .onAppear {
            if let memo = memo {
                text = memo.content
            } else {
                text = draft
            }
            if let resourceList = memo?.resourceList {
                viewModel.resourceList = resourceList
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
                        try await saveMemo()
                    }
                } label: {
                    Label("Save", systemImage: "paperplane")
                }
                .disabled(text.isEmpty || viewModel.imageUploading)
            }
        }
        .fullScreenCover(isPresented: $showingImagePicker, content: {
            ImagePicker { image in
                Task {
                    try await upload(images: [image])
                }
            }
            .edgesIgnoringSafeArea(.all)
        })
        .interactiveDismissDisabled()
    }

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack {
                editor()
                    .photosPicker(isPresented: $showingPhotoPicker, selection: Binding(get: {
                        viewModel.photos ?? []
                    }, set: { photos in
                        viewModel.photos = photos
                    }))
                    .onChange(of: viewModel.photos) { newValue in
                        Task {
                            guard let newValue = newValue else { return }
                            
                            if !newValue.isEmpty {
                                try await upload(images: newValue)
                                viewModel.photos = []
                            }
                        }
                    }
            }
        } else {
            NavigationView {
                editor()
                    .sheet(isPresented: $showingPhotoPicker) {
                        LegacyPhotoPicker { images in
                            Task {
                                try await upload(images: images)
                            }
                        }
                    }
            }
        }
    }
    
    @available(iOS 16, *)
    private func upload(images: [PhotosPickerItem]) async throws {
        do {
            viewModel.imageUploading = true
            for item in images {
                let imageData = try await item.loadTransferable(type: Data.self)
                if let imageData = imageData, let image = UIImage(data: imageData) {
                    try await viewModel.upload(image: image)
                }
            }
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
        viewModel.imageUploading = false
    }
    
    private func upload(images: [UIImage]) async throws {
        do {
            viewModel.imageUploading = true
            for image in images {
                try await viewModel.upload(image: image)
            }
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
        viewModel.imageUploading = false
    }
    
    private func saveMemo() async throws {
        do {
            if let memo = memo {
                try await memosViewModel.editMemo(id: memo.id, content: text, resourceIdList: viewModel.resourceList.map { $0.id })
            } else {
                try await memosViewModel.createMemo(content: text, resourceIdList: viewModel.resourceList.map { $0.id })
                draft = ""
            }
            text = ""
            dismiss()
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
    }
}

struct MemoInput_Previews: PreviewProvider {
    static var previews: some View {
        MemoInput(memo: nil)
            .environmentObject(MemosViewModel())
            .environmentObject(MemoInputViewModel())
    }
}
