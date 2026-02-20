import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Models
import Account
import DesignSystem
import SwiftData
#if canImport(JournalingSuggestions) && os(iOS) && !targetEnvironment(macCatalyst)
@_weakLinked @preconcurrency import JournalingSuggestions
#endif

private let listItemSymbolList = ["- [ ] ", "- [x] ", "- [X] ", "* ", "- "]

@MainActor
public struct MemoEditor: View {
    public let memo: StoredMemo?
    public let actions: MemoEditorActions

    @Environment(AccountViewModel.self) private var userState
    @Environment(AccountManager.self) private var accountManager
    @State private var viewModel = MemoEditorViewModel()

    @State private var text = ""
    @State private var selection: TextSelection?
    @State private var isApplyingAutoContinuation = false

    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var showingPhotoPicker = false
    @State private var showingImagePicker = false
    @State private var showingFilePicker = false
    @State private var showingJournalingSuggestionsPicker = false
    @State private var submitError: Error?
    @State private var showingErrorToast = false
    @State private var availableTags: [Tag] = []

    public init(memo: StoredMemo?, actions: MemoEditorActions) {
        self.memo = memo
        self.actions = actions
    }

    private var draftUserDefaults: UserDefaults {
        UserDefaults(suiteName: AppInfo.groupContainerIdentifier) ?? .standard
    }

    private var draftStorageKey: String {
        "draft.\(accountManager.currentAccount?.key ?? "default")"
    }

    private var draft: String {
        get {
            draftUserDefaults.string(forKey: draftStorageKey) ?? ""
        }
        nonmutating set {
            draftUserDefaults.set(newValue, forKey: draftStorageKey)
        }
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
            onPickJournalingSuggestion: {
                showingJournalingSuggestionsPicker = true
            },
            supportsJournalingSuggestions: supportsJournalingSuggestions,
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
                TextEditor(text: $text, selection: $selection)
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
                selection = .init(insertionPoint: text.endIndex)
                viewModel.visibility = memo.visibility
            } else {
                text = draft
                selection = .init(insertionPoint: text.endIndex)
                viewModel.visibility = userState.currentUser?.defaultVisibility ?? .private
            }
            if let memo {
                viewModel.resourceList = memo.resources.filter { !$0.softDeleted }.sorted { $0.createdAt > $1.createdAt }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                focused = true
            }
        }
        .onChange(of: text) { oldValue, newValue in
            applyAutoListContinuationIfNeeded(oldValue: oldValue, newValue: newValue)
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
            withJournalingSuggestionsPicker(
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
            )
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
            selection = nil
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

    private var supportsJournalingSuggestions: Bool {
#if canImport(JournalingSuggestions) && os(iOS) && !targetEnvironment(macCatalyst)
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return false
        }
        if UIDevice.current.userInterfaceIdiom == .mac {
            return false
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
        }
        return true
#else
        return false
#endif
    }

    private func insert(tag: Tag?) {
        let tagText = "#\(tag?.name ?? "") "
        insertAtSelection(tagText)
    }

    private func toggleTodoItem() {
        let currentText = text
        guard let currentSelection = currentSelectionRange() else { return }
        let lowerOffset = currentText.distance(from: currentText.startIndex, to: currentSelection.lowerBound)
        let upperOffset = currentText.distance(from: currentText.startIndex, to: currentSelection.upperBound)

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
            let newLower = text.index(text.startIndex, offsetBy: lowerOffset + offset)
            let newUpper = text.index(text.startIndex, offsetBy: upperOffset + offset)
            selection = TextSelection(range: newLower..<newUpper)
            return
        }

        text = contentBeforeCurrentLine + "- [ ] " + currentLine + contentAfterCurrentLine
        let newLower = text.index(text.startIndex, offsetBy: lowerOffset + "- [ ] ".count)
        let newUpper = text.index(text.startIndex, offsetBy: upperOffset + "- [ ] ".count)
        selection = TextSelection(range: newLower..<newUpper)
    }

    private func currentSelectionRange() -> Range<String.Index>? {
        guard let selection else { return nil }
        switch selection.indices {
        case .selection(let range):
            return range
        case .multiSelection(let rangeSet):
            return rangeSet.ranges.first
        @unknown default:
            return nil
        }
    }

    private func applyAutoListContinuationIfNeeded(oldValue: String, newValue: String) {
        guard !isApplyingAutoContinuation else {
            isApplyingAutoContinuation = false
            return
        }

        guard
            let edit = detectSingleEdit(old: oldValue, new: newValue),
            edit.replacedRange.lowerBound == edit.replacedRange.upperBound,
            edit.insertedText == "\n"
        else {
            return
        }

        let insertionPoint = edit.replacedRange.lowerBound

        let currentText = oldValue
        let contentBefore = currentText[currentText.startIndex..<insertionPoint]
        let lastLineBreak = contentBefore.lastIndex(of: "\n")
        let nextLineBreak = currentText[insertionPoint...].firstIndex(of: "\n") ?? currentText.endIndex
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

            if currentLine.count <= prefixStr.count || currentText.index(currentLine.startIndex, offsetBy: prefixStr.count) >= insertionPoint {
                break
            }

            let insertionOffset = currentText.distance(from: currentText.startIndex, to: insertionPoint)
            let updatedText = currentText[currentText.startIndex..<insertionPoint] + "\n" + prefixStr + currentText[insertionPoint..<currentText.endIndex]
            let cursorOffset = insertionOffset + prefixStr.count + 1
            let cursor = updatedText.index(updatedText.startIndex, offsetBy: cursorOffset)

            isApplyingAutoContinuation = true
            text = String(updatedText)
            selection = TextSelection(range: cursor..<cursor)
            return
        }
    }

    private func detectSingleEdit(old: String, new: String) -> (replacedRange: Range<String.Index>, insertedText: Substring)? {
        var oldStart = old.startIndex
        var newStart = new.startIndex
        while oldStart < old.endIndex, newStart < new.endIndex, old[oldStart] == new[newStart] {
            old.formIndex(after: &oldStart)
            new.formIndex(after: &newStart)
        }

        if oldStart == old.endIndex, newStart == new.endIndex {
            return nil
        }

        var oldEnd = old.endIndex
        var newEnd = new.endIndex
        while oldEnd > oldStart, newEnd > newStart {
            let oldPrev = old.index(before: oldEnd)
            let newPrev = new.index(before: newEnd)
            if old[oldPrev] != new[newPrev] {
                break
            }
            oldEnd = oldPrev
            newEnd = newPrev
        }

        return (oldStart..<oldEnd, new[newStart..<newEnd])
    }

    private func insertAtSelection(_ insertedText: String) {
        guard let selectionRange = currentSelectionRange() else {
            text += insertedText
            selection = .init(insertionPoint: text.endIndex)
            return
        }

        let lowerOffset = text.distance(from: text.startIndex, to: selectionRange.lowerBound)
        text = text.replacingCharacters(in: selectionRange, with: insertedText)
        let cursor = text.index(text.startIndex, offsetBy: lowerOffset + insertedText.count)
        selection = TextSelection(range: cursor..<cursor)
    }

    @inline(never)
    private func withJournalingSuggestionsPicker<Content: View>(_ content: Content) -> AnyView {
#if canImport(JournalingSuggestions) && os(iOS) && !targetEnvironment(macCatalyst)
        if supportsJournalingSuggestions {
            return withNativeJournalingSuggestionsPicker(AnyView(content))
        }
#endif
        return AnyView(content)
    }

#if canImport(JournalingSuggestions) && os(iOS) && !targetEnvironment(macCatalyst)
    @inline(never)
    private func withNativeJournalingSuggestionsPicker(_ content: AnyView) -> AnyView {
        AnyView(
            content
                .journalingSuggestionsPicker(isPresented: $showingJournalingSuggestionsPicker) { suggestion in
                    await insertJournalingSuggestion(suggestion)
                }
        )
    }

    private func insertJournalingSuggestion(_ suggestion: JournalingSuggestion) async {
        await attachJournalingSuggestionAssets(from: suggestion)
        let snippet = await journalingSuggestionSnippet(from: suggestion)
        guard !snippet.isEmpty else { return }
        let content = text.isEmpty ? snippet : "\n\n\(snippet)"
        insertAtSelection(content)
    }

    private func attachJournalingSuggestionAssets(from suggestion: JournalingSuggestion) async {
        let urls = await journalingSuggestionAssetURLs(from: suggestion)
        guard !urls.isEmpty else { return }

        var firstError: Error?
        for url in urls {
            do {
                try await viewModel.upload(fileURL: url)
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if let firstError {
            submitError = firstError
            showingErrorToast = true
        }
    }

    private func journalingSuggestionAssetURLs(from suggestion: JournalingSuggestion) async -> [URL] {
        var urls: [URL] = []

        let photos = await suggestion.content(forType: JournalingSuggestion.Photo.self)
        for photo in photos where !urls.contains(photo.photo) {
            urls.append(photo.photo)
        }

        let livePhotos = await suggestion.content(forType: JournalingSuggestion.LivePhoto.self)
        for livePhoto in livePhotos {
            if !urls.contains(livePhoto.image) {
                urls.append(livePhoto.image)
            }
        }

        return urls
    }

    private func journalingSuggestionSnippet(from suggestion: JournalingSuggestion) async -> String {
        var lines: [String] = []
        let title = suggestion.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            lines.append(title)
        }

        let reflections = await suggestion.content(forType: JournalingSuggestion.Reflection.self)
        let prompts = reflections.map(\.prompt).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        lines.append(contentsOf: prompts.map { "- \($0)" })

        if let date = suggestion.date {
            lines.append("")
            lines.append("_\(formattedSuggestionDateInterval(date))_")
        }

        return lines.joined(separator: "\n")
    }

    private func formattedSuggestionDateInterval(_ interval: DateInterval) -> String {
        let formatter = Date.IntervalFormatStyle(date: .abbreviated, time: .shortened)
        return (interval.start..<interval.end).formatted(formatter)
    }
#endif
}
