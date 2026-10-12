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

@MainActor
public struct MemoEditor: View {
    public let memo: StoredMemo?
    public let actions: MemoEditorActions

    @Environment(AccountManager.self) private var accountManager
    @State private var viewModel = MemoEditorViewModel()

    @State private var text = ""
    @State private var selection: TextSelection?
    @State private var isComposing = false
    @State private var textController = TextViewController()

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
    @State private var attachmentImporter = MemoAttachmentImporter()
    @State private var showingCloseConfirmation = false

    public init(memo: StoredMemo?, actions: MemoEditorActions) {
        self.memo = memo
        self.actions = actions
    }

    private var currentDraft: MemoDraft {
        MemoDraft(text: text, visibility: viewModel.visibility, resourceIDs: viewModel.resourceList.map(\.id))
    }

    private var isCurrentAccount: Bool {
        draftStore?.accountKey == accountManager.currentAccount?.key && draftStore != nil
    }
    private var isBusy: Bool { isSaving || importingCount > 0 || attachmentImporter.isImporting }
    private var canSave: Bool { !isBusy && isCurrentAccount && !attachmentImporter.hasUnfinishedImports && currentDraft.hasContent }

    private func restoreDraft() {
        guard draftStore == nil, let accountKey = memo?.accountKey ?? accountManager.currentAccount?.key else { return }
        let service = accountManager.service(for: accountKey)
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
            guard let resource = service?.resource(id: id),
                  resource.accountKey == accountKey, !resource.softDeleted else { return nil }
            return resource
        }
        selection = .init(insertionPoint: text.endIndex)
        initialDraft = original
        draftStore = store
        viewModel.accountKey = accountKey
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
        textController.commitComposition()
        if (memo != nil && currentDraft != initialDraft) || attachmentImporter.hasUnfinishedImports {
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
            tagQuery: isComposing ? nil : MemoTextEditing.tagToken(in: textController.text ?? text, selection: currentNSSelection() ?? NSRange())?.query,
            isComposing: isComposing,
            onInsertTag: { tag in
                insert(tag: tag)
                focused = true
            },
            onToggleTodo: {
                toggleTodoItem()
                focused = true
            },
            onFormat: { format in
                apply(format)
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
                    .disabled(isSaving || !isCurrentAccount)
                    .padding(.horizontal)
                TextView(
                    text: $text, selection: $selection, isFocused: $focused,
                    controller: textController, onFormat: { apply($0) },
                    onCompositionChange: { isComposing = $0 }
                )
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
                if draftStore != nil, !isCurrentAccount {
                    Label("input.account-changed", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                }
                attachmentImportStatus
                MemoEditorResourceView(viewModel: viewModel)
                    .disabled(isBusy || !isCurrentAccount)
            }
            .safeAreaInset(edge: .bottom) {
                toolbar()
                    .disabled(isBusy || !isCurrentAccount)
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
        .task(id: accountManager.currentAccount?.key) {
            guard isCurrentAccount else { return }
            do {
                let tags = try await actions.loadTags()
                guard !Task.isCancelled, isCurrentAccount else { return }
                availableTags = tags
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
            Button("input.save") { Task { await saveMemo() } }
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
                    await upload(images: [image])
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
        .interactiveDismissDisabled(isBusy || attachmentImporter.hasUnfinishedImports || draftSaveFailed || (memo != nil && currentDraft != initialDraft))
    }

    private var saveButton: some View {
        Button("input.save") {
            Task { await saveMemo() }
        }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!canSave)
    }

    @ViewBuilder
    private var attachmentImportStatus: some View {
        if attachmentImporter.hasUnfinishedImports {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(attachmentImporter.items) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.input.name).lineLimit(1)
                                if case .failed(let message) = item.state {
                                    Label(message, systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(.red)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            if case .failed = item.state {
                                Button("common.retry", systemImage: "arrow.clockwise") {
                                    Task {
                                        await attachmentImporter.retry(id: item.id)
                                        persistDraft()
                                    }
                                }
                                .labelStyle(.iconOnly)
                                .disabled(isBusy || !isCurrentAccount)
                                Button("input.remove-attachment", systemImage: "xmark.circle") {
                                    attachmentImporter.remove(id: item.id)
                                }
                                .labelStyle(.iconOnly)
                                .disabled(isBusy)
                            } else {
                                ProgressView()
                            }
                        }
                    }
                }
                .font(.footnote)
                .padding(.horizontal)
            }
            .frame(maxHeight: 100)
        }
    }

    public var body: some View {
        NavigationStack {
            withJournalingSuggestionsPicker(
                editor()
                .photosPicker(isPresented: $showingPhotoPicker, selection: $viewModel.photos)
                .onChange(of: viewModel.photos) { _, newValue in
                    Task {
                        if !newValue.isEmpty {
                            viewModel.photos = []
                            await upload(images: newValue)
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        Task {
                            await upload(fileURLs: urls)
                        }
                    case .failure(let error):
                        submitError = error
                        showingErrorToast = true
                    }
                }
            )
        }
    }

    private func upload(images: [PhotosPickerItem]) async {
        let editorViewModel = viewModel
        await attachmentImporter.importItems(images.enumerated().map { index, item in
            MemoAttachmentImporter.Input(name: "\(NSLocalizedString("input.photos", comment: "Photos")) \(index + 1)") {
                let contentType = item.supportedContentTypes.first
                let imageData = try await item.loadTransferable(type: Data.self)
                guard let imageData else { throw MemoEditorError.unreadableAttachment }

                let fileExtension = contentType?.preferredFilenameExtension
                let filename = fileExtension.map { "\(UUID().uuidString).\($0)" } ?? "\(UUID().uuidString).dat"
                let mimeType = contentType?.preferredMIMEType ?? "application/octet-stream"
                try await editorViewModel.upload(data: imageData, filename: filename, mimeType: mimeType)
            }
        })
        persistDraft()
    }

    private func upload(images: [UIImage]) async {
        let editorViewModel = viewModel
        await attachmentImporter.importItems(images.enumerated().map { index, image in
            MemoAttachmentImporter.Input(name: "\(NSLocalizedString("input.photos", comment: "Photos")) \(index + 1)") {
                guard let data = image.jpegData(compressionQuality: 1.0) else { throw MemoEditorError.unreadableAttachment }
                try await editorViewModel.upload(data: data, filename: "\(UUID().uuidString).jpg", mimeType: "image/jpeg")
            }
        })
        persistDraft()
    }

    private func upload(fileURLs: [URL]) async {
        let editorViewModel = viewModel
        await attachmentImporter.importItems(fileURLs.map { url in
            .init(name: url.lastPathComponent) {
                try await editorViewModel.upload(fileURL: url)
            }
        })
        persistDraft()
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
            let editorViewModel = viewModel
            let filename = scannedDocumentFilename()
            await attachmentImporter.importItems([.init(name: filename) {
                let data = try ScannedDocumentPDFBuilder.makePDFData(from: images)
                try await editorViewModel.upload(data: data, filename: filename, mimeType: "application/pdf")
            }])
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

    private func saveMemo() async {
        guard canSave else { return }
        textController.commitComposition()
        let wasFocused = focused
        focused = false
        isSaving = true
        defer { isSaving = false }
        // Use the committed UIKit text, including any final IME candidate.
        text = textController.text ?? text
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
        guard !textController.isComposing else { return }
        let content = textController.text ?? text
        let selection = currentNSSelection() ?? NSRange(location: content.utf16.count, length: 0)
        apply(MemoTextEditing.tagEdit(name: tag?.name, in: content, selection: selection))
    }

    private func toggleTodoItem() {
        guard !textController.isComposing, let selection = currentNSSelection() else { return }
        apply(MarkdownFormatter.toggleTodo(in: textController.text ?? text, selection: selection))
    }

    private func apply(_ format: MarkdownFormat) {
        guard !textController.isComposing else { return }
        let content = textController.text ?? text
        let selection = currentNSSelection() ?? NSRange(location: content.utf16.count, length: 0)
        apply(MarkdownFormatter.edit(for: format, in: content, selection: selection))
    }

    /// Prefers editing through the text view so the change can be undone.
    private func apply(_ edit: MarkdownEdit) {
        guard textController.apply(edit) == .unavailable, edit.isValid(in: text) else { return }
        text = edit.applied(to: text)
        if let range = EditorTextRange.characters(edit.selection, in: text) {
            selection = TextSelection(range: range)
        }
    }

    private func currentNSSelection() -> NSRange? {
        if let range = textController.selectedRange { return range }
        guard let range = currentSelectionRange(),
              let lower = String.Index(range.lowerBound, within: text),
              let upper = String.Index(range.upperBound, within: text) else { return nil }
        return NSRange(lower..<upper, in: text)
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

    private func insertAtSelection(_ insertedText: String) {
        let selection = currentNSSelection() ?? NSRange(location: (text as NSString).length, length: 0)
        apply(MarkdownEdit(
            range: selection,
            replacement: insertedText,
            selection: NSRange(location: selection.location + (insertedText as NSString).length, length: 0)
        ))
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

        await upload(fileURLs: urls)
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
