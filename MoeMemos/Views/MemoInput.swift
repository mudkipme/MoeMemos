//
//  MemoInput.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI
import PhotosUI
import MemosService
import Models
import Account

@MainActor
struct MemoInput: View {
    let memo: MemosMemo?
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AccountViewModel.self) var userState: AccountViewModel
    @Environment(AccountManager.self) var accountManager: AccountManager
    @State private var viewModel = MemoInputViewModel()

    @State private var text = ""
    @State private var selection: Range<String.Index>? = nil
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
                                    insert(tag: tag)
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
                        insert(tag: nil)
                    } label: {
                        Image(systemName: "number")
                    }
                }
                
                Button {
                    toggleTodoItem()
                } label: {
                    Image(systemName: "checkmark.square")
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
            VStack(alignment: .leading) {
                privacyMenu
                    .padding(.horizontal)
                TextView(text: $text, selection: $selection, shouldChangeText: shouldChangeText(in:replacementText:))
                    .focused($focused)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("input.placeholder")
                                .foregroundColor(.secondary)
                                .padding(EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5))
                        }
                    }
                    .padding(.horizontal)
                MemoInputResourceView(viewModel: viewModel)
            }
            .padding(.bottom, 40)
            toolbar()
        }
        
        .onAppear {
            if let memo = memo {
                text = memo.content
                viewModel.visibility = .init(memo.visibility ?? .PRIVATE)
            } else {
                text = draft
                viewModel.visibility = userState.currentUser?.defaultVisibility ?? .private
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
        .navigationTitle(memo == nil ? NSLocalizedString("input.compose", comment: "Compose") : NSLocalizedString("input.edit", comment: "Edit"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("input.close")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        try await saveMemo()
                    }
                } label: {
                    Label("input.save", systemImage: "paperplane")
                }
                .disabled((text.isEmpty && viewModel.resourceList.isEmpty) || viewModel.imageUploading || viewModel.saving)
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
        NavigationStack {
            editor()
                .photosPicker(isPresented: $showingPhotoPicker, selection: $viewModel.photos)
                .onChange(of: viewModel.photos) { _, newValue in
                    Task {
                        if !newValue.isEmpty {
                            try await upload(images: newValue)
                            viewModel.photos = []
                        }
                    }
                }
        }
    }
    
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
        viewModel.saving = true
        let tags = viewModel.extractCustomTags(from: text)
        do {
            try await memosViewModel.upsertTags(names: tags)
        } catch {
            print(error.localizedDescription)
        }
        
        do {
            if let memo = memo {
                try await memosViewModel.editMemo(id: memo.id, content: text, visibility: .init(memoVisibility: viewModel.visibility), resourceIdList: viewModel.resourceList.map { $0.id })
            } else {
                try await memosViewModel.createMemo(content: text, visibility: .init(memoVisibility: viewModel.visibility), resourceIdList: viewModel.resourceList.map { $0.id })
                draft = ""
            }
            text = ""
            dismiss()
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
        viewModel.saving = false
    }
    
    private var privacyMenu: some View {
      Menu {
        Section("input.visibility") {
        ForEach(accountManager.currentService?.memoVisibilities() ?? [.private], id: \.self) { visibility in
            Button {
              viewModel.visibility = visibility
            } label: {
              Label(visibility.title, systemImage: visibility.iconName)
            }
          }
        }
      } label: {
        HStack {
          Label(viewModel.visibility.title, systemImage: viewModel.visibility.iconName)
          Image(systemName: "chevron.down")
        }
        .font(.footnote)
        .padding(4)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(.green, lineWidth: 1)
        )
      }
    }
    
    private func insert(tag: Tag?) {
        let tagText = "#\(tag?.name ?? "") "
        guard let selection = selection else {
            text += tagText
            return
        }
        
        text = text.replacingCharacters(in: selection, with: tagText)
        let index = text.index(selection.lowerBound, offsetBy: tagText.count)
        self.selection = index..<text.index(selection.lowerBound, offsetBy: tagText.count)
    }
    
    private func toggleTodoItem() {
        let currentText = text
        guard let currentSelection = selection else { return }
        
        let contentBefore = currentText[currentText.startIndex..<currentSelection.lowerBound]
        let lastLineBreak = contentBefore.lastIndex(of: "\n")
        let nextLineBreak = currentText[currentSelection.lowerBound...].firstIndex(of: "\n") ?? currentText.endIndex
        let currentLine: Substring
        if let lastLineBreak = lastLineBreak {
            currentLine = currentText[currentText.index(after: lastLineBreak)..<nextLineBreak]
        } else {
            currentLine = currentText[currentText.startIndex..<nextLineBreak]
        }
    
        let contentBeforeCurrentLine = currentText[currentText.startIndex..<currentLine.startIndex]
        let contentAfterCurrentLine = currentText[nextLineBreak..<currentText.endIndex]
        
        for prefixStr in listItemSymbolList {
            if (!currentLine.hasPrefix(prefixStr)) {
                continue
            }
            
            if prefixStr == "- [ ] " {
                text = contentBeforeCurrentLine + "- [x] " + currentLine[currentLine.index(currentLine.startIndex, offsetBy: prefixStr.count)..<currentLine.endIndex] + contentAfterCurrentLine
                return
            }
            
            let offset = "- [ ] ".count - prefixStr.count
            text = contentBeforeCurrentLine + "- [ ] " + currentLine[currentLine.index(currentLine.startIndex, offsetBy: prefixStr.count)..<currentLine.endIndex] + contentAfterCurrentLine
            selection = text.index(currentSelection.lowerBound, offsetBy: offset)..<text.index(currentSelection.upperBound, offsetBy: offset)
            return
        }
        
        text = contentBeforeCurrentLine + "- [ ] " + currentLine + contentAfterCurrentLine
        selection = text.index(currentSelection.lowerBound, offsetBy: "- [ ] ".count)..<text.index(currentSelection.upperBound, offsetBy: "- [ ] ".count)
    }
    
    private func shouldChangeText(in range: Range<String.Index>, replacementText text: String) -> Bool {
        if text != "\n" || range.upperBound != range.lowerBound {
            return true
        }
        
        let currentText = self.text
        let contentBefore = currentText[currentText.startIndex..<range.lowerBound]
        let lastLineBreak = contentBefore.lastIndex(of: "\n")
        let nextLineBreak = currentText[range.lowerBound...].firstIndex(of: "\n") ?? currentText.endIndex
        let currentLine: Substring
        if let lastLineBreak = lastLineBreak {
            currentLine = currentText[currentText.index(after: lastLineBreak)..<nextLineBreak]
        } else {
            currentLine = currentText[currentText.startIndex..<nextLineBreak]
        }
        
        for prefixStr in listItemSymbolList {
            if (!currentLine.hasPrefix(prefixStr)) {
                continue
            }
            
            if currentLine.count <= prefixStr.count || currentText.index(currentLine.startIndex, offsetBy: prefixStr.count) >= range.lowerBound {
                break
            }
            
            self.text = currentText[currentText.startIndex..<range.lowerBound] + "\n" + prefixStr + currentText[range.upperBound..<currentText.endIndex]
            selection = self.text.index(range.lowerBound, offsetBy: prefixStr.count + 1)..<self.text.index(range.upperBound, offsetBy: prefixStr.count + 1)
            return false
        }

        return true
    }
}


extension PhotosPickerItem: @unchecked Sendable {}
