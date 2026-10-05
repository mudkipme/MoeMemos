//
//  LocalAccountView.swift
//
//
//  Created by Codex on 2026/2/8.
//

import MemoData
import SwiftUI
import Models
import UniformTypeIdentifiers

public struct LocalAccountView: View {
    @State private var user: User? = nil
    @State private var isBusy = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var exportedZipURL: URL?
    @State private var showingImporter = false
    @State private var showingPreview = false
    @State private var preparedImport: PreparedLocalImport?
    @State private var operation: Task<Void, Never>?
    private let accountKey: String
    @Environment(AccountManager.self) private var accountManager
    @Environment(AccountViewModel.self) private var accountViewModel
    @Environment(\.presentationMode) var presentationMode
    private var account: Account? { accountManager.account(for: accountKey) }

    public init(accountKey: String) {
        self.accountKey = accountKey
    }

    public var body: some View {
        List {
            if let user = user {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundStyle(.secondary)
                    Text(user.nickname)
                        .font(.title3)
                    if let email = user.email, email != user.nickname && !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding([.top, .bottom], 10)
            }

            if accountKey != accountManager.currentAccount?.key {
                Section {
                    Button {
                        Task {
                            try await accountViewModel.switchTo(accountKey: accountKey)
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("account.switch-account")
                            Spacer()
                        }
                    }
                }
            }

            Section {
                Button("account.local-export-button", action: startExport)
                    .disabled(isBusy || preparedImport != nil)
                Button("account.local-import-button") { showingImporter = true }
                    .disabled(isBusy || preparedImport != nil)

                if isBusy { ProgressView() }
                if let statusMessage {
                    Text(statusMessage).font(.footnote).foregroundStyle(.secondary)
                }
                if let exportedZipURL {
                    ShareLink(item: exportedZipURL) {
                        Label("account.local-export-share-zip", systemImage: "square.and.arrow.up")
                    }
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("account.local-backup")
            } footer: {
                Text("account.local-backup-description")
            }

            Section {
                Text("account.local-account-cannot-be-removed")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("account.account-detail")
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.zip]) { result in
            switch result {
            case .success(let url): prepareImport(url)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .alert("account.local-import-button", isPresented: $showingPreview) {
            Button("common.cancel", role: .cancel) { preparedImport = nil }
            Button("account.local-restore-button", action: restore)
        } message: {
            Text(previewMessage)
        }
        .onDisappear {
            operation?.cancel()
            preparedImport = nil
            clearExport()
        }
        .task {
            guard let account = account else { return }
            if let cached = accountViewModel.users.first(where: { $0.accountKey == accountKey }) {
                user = cached
            } else {
                user = try? await account.toUser()
            }
        }
    }

    private var previewMessage: String {
        guard let preview = preparedImport?.preview else { return "" }
        var message = String(format: NSLocalizedString("account.local-import-preview", comment: ""), preview.memos, preview.attachments)
        message += "\n\n" + NSLocalizedString("account.local-import-additive", comment: "")
        if preview.existingMemos > 0 {
            message += "\n\n" + String(format: NSLocalizedString("account.local-import-existing", comment: ""), preview.existingMemos)
        }
        if preview.legacy { message += "\n\n" + NSLocalizedString("account.local-import-legacy", comment: "") }
        if preview.ignoredFiles > 0 {
            message += "\n\n" + String(format: NSLocalizedString("account.local-import-ignored", comment: ""), preview.ignoredFiles)
        }
        return message
    }

    private func clearExport() {
        if let exportedZipURL { try? FileManager.default.removeItem(at: exportedZipURL) }
        exportedZipURL = nil
    }

    private func startExport() {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        statusMessage = NSLocalizedString("account.local-export-progress-exporting", comment: "")
        clearExport()
        operation = Task { @MainActor in
            defer { isBusy = false }
            do {
                let url = try await accountManager.localBackupService.export()
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                exportedZipURL = url
                statusMessage = NSLocalizedString("account.local-export-progress-complete", comment: "")
            } catch {
                statusMessage = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func prepareImport(_ url: URL) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        statusMessage = NSLocalizedString("account.local-import-preparing", comment: "")
        operation = Task { @MainActor in
            defer { isBusy = false }
            do {
                let prepared = try await accountManager.localBackupService.prepareImport(from: url)
                guard !Task.isCancelled else { return }
                preparedImport = prepared
                statusMessage = nil
                showingPreview = true
            } catch {
                statusMessage = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        guard let prepared = preparedImport, !isBusy else { return }
        preparedImport = nil
        isBusy = true
        errorMessage = nil
        statusMessage = NSLocalizedString("account.local-import-restoring", comment: "")
        operation = Task { @MainActor in
            defer { isBusy = false }
            do {
                let result = try await accountManager.restoreLocalBackup(prepared)
                statusMessage = String(format: NSLocalizedString("account.local-import-result", comment: ""),
                    result.importedMemos, result.importedAttachments, result.skippedMemos, result.skippedAttachments)
            } catch {
                statusMessage = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}
