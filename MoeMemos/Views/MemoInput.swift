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
    @State private var imageUploading = false
    
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
        
        Button {
            showingImagePicker = true
        } label: {
            Image(systemName: "camera")
        }
        
        Spacer()
    }
    
    @ViewBuilder
    private func editor() -> some View {
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
            
            if !viewModel.resourceList.isEmpty || imageUploading {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack {
                        ForEach(viewModel.resourceList, id: \.id) { resource in
                            if resource.type.hasPrefix("image/") {
                                ResourceCard(resource: resource, resourceManager: viewModel)
                            } else {
                                Attachment(resource: resource)
                            }
                        }
                        if imageUploading {
                            Color.clear
                                .scaledToFill()
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    ProgressView()
                                }
                        }
                    }
                    .frame(height: 80)
                    .padding([.leading, .trailing, .bottom])
                }
            }
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
                .disabled(text.isEmpty || imageUploading)
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                toolbar()
            }
        }
        .fullScreenCover(isPresented: $showingImagePicker, content: {
            ImagePicker { image in
                Task {
                    try await upload(images: [image])
                }
            }
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
            imageUploading = true
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
        imageUploading = false
    }
    
    private func upload(images: [UIImage]) async throws {
        do {
            imageUploading = true
            for image in images {
                try await viewModel.upload(image: image)
            }
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
        imageUploading = false
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
