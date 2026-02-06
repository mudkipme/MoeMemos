import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Models
import Account
import DesignSystem
import SwiftData

private let listItemSymbolList = ["- [ ] ", "- [x] ", "- [X] ", "* ", "- "]

@MainActor
public struct MemoEditor: View {
    public let memo: StoredMemo?
    public let actions: MemoEditorActions

    @Environment(AccountViewModel.self) private var userState
    @Environment(AccountManager.self) private var accountManager
    @State private var viewModel = MemoEditorViewModel()

    @State private var text = ""
    @State private var selection: Range<String.Index>? = nil
    @AppStorage("draft") private var draft = ""

    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var showingPhotoPicker = false
    @State private var showingImagePicker = false
    @State private var showingFilePicker = false
    @State private var submitError: Error?
    @State private var showingErrorToast = false
    @State private var availableTags: [Tag] = []

    public init(memo: StoredMemo?, actions: MemoEditorActions) {
        self.memo = memo
        self.actions = actions
    }

    @ViewBuilder
    private func toolbar() -> some View {
        MemoEditorToolbar(
            tags: availableTags,
            onInsertTag: { tag in
                insert(tag: tag)
            },
            onToggleTodo: {
                toggleTodoItem()
            },
            onPickPhotos: {
                showingPhotoPicker = true
            },
            onPickCamera: {
                showingImagePicker = true
            },
            onPickFiles: {
                showingFilePicker = true
            }
        )
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
                MemoEditorResourceView(viewModel: viewModel)
            }
            .safeAreaInset(edge: .bottom) {
                toolbar()
            }
        }

        .onAppear {
            if let memo = memo {
                text = memo.content
                viewModel.visibility = memo.visibility
            } else {
                text = draft
                viewModel.visibility = userState.currentUser?.defaultVisibility ?? .private
            }
            if let memo {
                viewModel.resourceList = memo.resources.filter { !$0.isDeleted }.sorted { $0.createdAt > $1.createdAt }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                focused = true
            }
        }
        .task {
            do {
                availableTags = try await actions.loadTags()
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
                .disabled((text.isEmpty && viewModel.resourceList.isEmpty))
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

    public var body: some View {
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
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        Task {
                            try await upload(fileURL: url)
                        }
                    case .failure(let error):
                        submitError = error
                        showingErrorToast = true
                    }
                }
        }
    }

    private func upload(images: [PhotosPickerItem]) async throws {
        do {
            for item in images {
                let contentType = item.supportedContentTypes.first
                let imageData = try await item.loadTransferable(type: Data.self)
                guard let imageData = imageData else { continue }

                let fileExtension = contentType?.preferredFilenameExtension
                let filename = fileExtension.map { "\(UUID().uuidString).\($0)" } ?? "\(UUID().uuidString).dat"
                let mimeType = contentType?.preferredMIMEType ?? "application/octet-stream"
                try await viewModel.upload(data: imageData, filename: filename, mimeType: mimeType)
            }
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
    }

    private func upload(images: [UIImage]) async throws {
        do {
            for image in images {
                guard let data = image.jpegData(compressionQuality: 1.0) else { continue }
                try await viewModel.upload(data: data, filename: "\(UUID().uuidString).jpg", mimeType: "image/jpeg")
            }
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
    }

    private func upload(fileURL: URL) async throws {
        do {
            try await viewModel.upload(fileURL: fileURL)
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
    }

    private func saveMemo() async throws {
        let tags = viewModel.extractCustomTags(from: text)

        do {
            let resourceIds = viewModel.resourceList.map(\.id)
            if let memo = memo {
                try await actions.editMemo(memo.id, text, viewModel.visibility, resourceIds, tags)
            } else {
                try await actions.createMemo(text, viewModel.visibility, resourceIds, tags)
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

    private var privacyMenu: some View {
      Menu {
        Section("input.visibility") {
        ForEach(availableVisibilities, id: \.self) { visibility in
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

    private var availableVisibilities: [MemoVisibility] {
        accountManager.currentService?.memoVisibilities() ?? [.private]
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
