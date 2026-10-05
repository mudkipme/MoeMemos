import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Models
import MemoData
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

    @Environment(AccountManager.self) private var accountManager
    @State private var viewModel = MemoEditorViewModel()

    @State private var text = ""
    @State private var selection: TextSelection?
    @State private var isApplyingAutoContinuation = false

    @State private var focused = false
    @State private var requestedInitialFocus = false
    @Environment(\.dismiss) private var dismiss

    @State private var showingPhotoPicker = false
    @State private var showingImagePicker = false
    @State private var showingDocumentScanner = false
    @State private var showingFilePicker = false
    @State private var showingJournalingSuggestionsPicker = false
    @State private var submitError: Error?
    @State private var showingErrorToast = false
    @State private var availableTags: [Tag] = []
    @State private var initialDraft: MemoDraft?
    @State private var draftStore: MemoDraftStore?
    @State private var lastPersistedDraft: MemoDraft?
    @State private var draftFeedback: String?
    @State private var draftSaveFailed = false
    @State private var finished = false
    @State private var isSaving = false
    @State private var importingCount = 0
    @State private var showingCloseConfirmation = false

    public init(memo: StoredMemo?, actions: MemoEditorActions) {
        self.memo = memo
        self.actions = actions
    }

    private var currentDraft: MemoDraft {
        MemoDraft(text: text, visibility: viewModel.visibility, resourceIDs: viewModel.resourceList.map(\.id))
    }

    private var isBusy: Bool { isSaving || importingCount > 0 }
    private var canSave: Bool { !isBusy && currentDraft.hasContent }

    private func restoreDraft() {
        guard draftStore == nil, let accountKey = accountManager.currentAccount?.key else { return }
        let store = MemoDraftStore(
            defaults: UserDefaults(suiteName: AppInfo.groupContainerIdentifier) ?? .standard,
            accountKey: accountKey,
            memoID: memo?.id
        )
        let resources = memo?.resources.filter { !$0.softDeleted }.sorted { $0.createdAt > $1.createdAt } ?? []
        let original = MemoDraft(
            text: memo?.content ?? "",
            visibility: memo?.visibility ?? accountManager.currentUser?.defaultVisibility ?? .private,
            resourceIDs: resources.map(\.id)
        )
        let savedDraft = store.load(defaultVisibility: original.visibility)
        let restored = savedDraft ?? original
        text = restored.text
        viewModel.visibility = restored.visibility
        viewModel.resourceList = restored.resourceIDs.compactMap { id in
            guard let resource = accountManager.currentService?.resource(id: id),
                  resource.accountKey == accountKey, !resource.softDeleted else { return nil }
            return resource
        }
        selection = .init(insertionPoint: text.endIndex)
        initialDraft = original
        draftStore = store
        if savedDraft == currentDraft, (memo == nil ? currentDraft.hasContent : currentDraft != original) {
            lastPersistedDraft = currentDraft
            draftFeedback = memo == nil ? "input.draft-restored" : "input.unsaved-changes-restored"
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard !finished else { return true }
        guard let draftStore else { return !currentDraft.hasContent }
        if (memo != nil && currentDraft == initialDraft) || (memo == nil && !currentDraft.hasContent) {
            draftStore.clear()
            lastPersistedDraft = currentDraft
            draftFeedback = nil
            draftSaveFailed = false
            return true
        }
        guard currentDraft != lastPersistedDraft || draftSaveFailed else { return true }
        do {
            try draftStore.save(currentDraft)
            lastPersistedDraft = currentDraft
            draftFeedback = memo == nil ? "input.draft-saved" : nil
            draftSaveFailed = false
            return true
        } catch {
            draftFeedback = "input.draft-save-failed"
            draftSaveFailed = true
            submitError = error
            showingErrorToast = true
            return false
        }
    }

    private func closeEditor() {
        guard !isBusy else { return }
        if memo != nil && currentDraft != initialDraft {
            showingCloseConfirmation = true
        } else {
            if persistDraft() {
                focused = false
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func toolbar() -> some View {
        MemoEditorToolbar(
            tags: availableTags,
            onInsertTag: { tag in
                insert(tag: tag)
                focused = true
            },
            onToggleTodo: {
                toggleTodoItem()
                focused = true
            },
            onPickJournalingSuggestion: {
                focused = false
                showingJournalingSuggestionsPicker = true
            },
            supportsJournalingSuggestions: supportsJournalingSuggestions,
            onPickPhotos: {
                focused = false
                showingPhotoPicker = true
            },
            onPickCamera: {
                focused = false
                showingImagePicker = true
            },
            supportsDocumentScanning: supportsDocumentScanning,
            onScanDocument: {
                focused = false
                showingDocumentScanner = true
            },
            onPickFiles: {
                focused = false
                showingFilePicker = true
            },
            isFocused: $focused
        )
    }

    @ViewBuilder
    private func editor() -> some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                privacyMenu
                    .disabled(isSaving)
                    .padding(.horizontal)
                TextView(text: $text, selection: $selection, isFocused: $focused)
                    .disabled(isSaving)
                    .accessibilityLabel(Text("input.memo-content"))
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("input.placeholder")
                                .foregroundColor(.secondary)
                                .padding(EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5))
                        }
                    }
                    .padding(.horizontal)
                if let draftFeedback, !isBusy {
                    Label(
                        LocalizedStringKey(draftFeedback),
                        systemImage: draftSaveFailed ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(draftSaveFailed ? Color.red : Color.secondary)
                    .padding(.horizontal)
                }
                if isBusy {
                    ProgressView(LocalizedStringKey(isSaving ? "input.saving" : "input.importing"))
                        .font(.footnote)
                        .padding(.horizontal)
                }
                MemoEditorResourceView(viewModel: viewModel)
                    .disabled(isBusy)
            }
            .safeAreaInset(edge: .bottom) {
                toolbar()
                    .disabled(isBusy)
            }
        }

        .onAppear {
            restoreDraft()
        }
        .task {
            guard !requestedInitialFocus else { return }
            requestedInitialFocus = true
            focused = true
        }
        .onChange(of: currentDraft) { _, _ in
            persistDraft()
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
            persistDraft()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            persistDraft()
        }
        .confirmationDialog("input.unsaved.title", isPresented: $showingCloseConfirmation, titleVisibility: .visible) {
            Button("input.save") { Task { try await saveMemo() } }
                .disabled(!canSave)
            Button("input.discard", role: .destructive) {
                finished = true
                draftStore?.clear()
                dismiss()
            }
            Button("input.keep-editing", role: .cancel) {}
        }
        .toast(isPresenting: $showingErrorToast, alertType: .systemImage("xmark.circle", submitError?.localizedDescription))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(memo == nil ? NSLocalizedString("input.compose", comment: "Compose") : NSLocalizedString("input.edit", comment: "Edit"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    closeEditor()
                } label: {
                    Text("input.close")
                }
                .disabled(isBusy)
            }

            ToolbarItem(placement: .confirmationAction) {
                if #available(iOS 26, *) {
                    saveButton.buttonStyle(.glassProminent)
                } else {
                    saveButton.fontWeight(.semibold)
                }
            }
            .prioritizeVisibility()
        }
        .fullScreenCover(isPresented: $showingImagePicker, content: {
            ImagePicker { image in
                Task {
                    try await upload(images: [image])
                }
            }
            .edgesIgnoringSafeArea(.all)
        })
#if canImport(VisionKit) && os(iOS) && !targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: $showingDocumentScanner) {
            DocumentScanner { result in
                Task {
                    await handleDocumentScan(result)
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
#endif
        .interactiveDismissDisabled(isBusy || draftSaveFailed || (memo != nil && currentDraft != initialDraft))
    }

    private var saveButton: some View {
        Button("input.save") {
            Task { try await saveMemo() }
        }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!canSave)
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
        importingCount += 1
        defer {
            importingCount -= 1
            persistDraft()
        }
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
        importingCount += 1
        defer {
            importingCount -= 1
            persistDraft()
        }
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
        importingCount += 1
        defer {
            importingCount -= 1
            persistDraft()
        }
        do {
            try await viewModel.upload(fileURL: fileURL)
            submitError = nil
        } catch {
            submitError = error
            showingErrorToast = true
        }
    }

#if canImport(VisionKit) && os(iOS) && !targetEnvironment(macCatalyst)
    private func handleDocumentScan(_ result: DocumentScanner.Result) async {
        importingCount += 1
        defer {
            importingCount -= 1
            persistDraft()
        }
        showingDocumentScanner = false

        switch result {
        case .success(let images):
            do {
                let data = try ScannedDocumentPDFBuilder.makePDFData(from: images)
                try await viewModel.upload(data: data, filename: scannedDocumentFilename(), mimeType: "application/pdf")
                submitError = nil
            } catch {
                submitError = error
                showingErrorToast = true
            }
        case .cancelled:
            break
        case .failure(let error):
            submitError = error
            showingErrorToast = true
        }
    }
#endif

    private var supportsDocumentScanning: Bool {
#if canImport(VisionKit) && os(iOS) && !targetEnvironment(macCatalyst)
        DocumentScanner.isSupported
#else
        false
#endif
    }

    private func scannedDocumentFilename(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "scan-\(formatter.string(from: date)).pdf"
    }

    private func saveMemo() async throws {
        guard canSave else { return }
        let wasFocused = focused
        focused = false
        isSaving = true
        defer { isSaving = false }
        let tags = viewModel.extractCustomTags(from: text)

        do {
            let resourceIds = viewModel.resourceList.map(\.id)
            if let memo = memo {
                try await actions.editMemo(memo.id, text, viewModel.visibility, resourceIds, tags)
            } else {
                try await actions.createMemo(text, viewModel.visibility, resourceIds, tags)
            }
            finished = true
            draftStore?.clear()
            text = ""
            selection = nil
            dismiss()
            submitError = nil
        } catch {
            focused = wasFocused
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
        let tagText = tag.map { "#\($0.name) " } ?? "#"
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

    private func applyAutoListContinuationIfNeeded(oldValue _: String, newValue: String) {
        guard !isApplyingAutoContinuation else {
            isApplyingAutoContinuation = false
            return
        }

        guard
            let selectionRange = currentSelectionRange(),
            selectionRange.lowerBound == selectionRange.upperBound,
            selectionRange.lowerBound > newValue.startIndex,
            newValue[newValue.index(before: selectionRange.lowerBound)] == "\n"
        else {
            return
        }

        let insertionPoint = selectionRange.lowerBound
        let newlineIndex = newValue.index(before: insertionPoint)
        let contentBefore = newValue[newValue.startIndex..<newlineIndex]
        let lastLineBreak = contentBefore.lastIndex(of: "\n")
        let currentLineStart = lastLineBreak.map { newValue.index(after: $0) } ?? newValue.startIndex
        let currentLine = newValue[currentLineStart..<newlineIndex]

        for prefixStr in listItemSymbolList {
            if (!currentLine.hasPrefix(prefixStr)) {
                continue
            }

            if currentLine.count <= prefixStr.count {
                break
            }

            let updatedText = newValue[..<insertionPoint] + prefixStr + newValue[insertionPoint...]
            let cursorOffset = newValue.distance(from: newValue.startIndex, to: insertionPoint) + prefixStr.count
            let cursor = updatedText.index(updatedText.startIndex, offsetBy: cursorOffset)

            isApplyingAutoContinuation = true
            text = String(updatedText)
            selection = TextSelection(range: cursor..<cursor)
            return
        }
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
        importingCount += 1
        defer {
            importingCount -= 1
            persistDraft()
        }
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
