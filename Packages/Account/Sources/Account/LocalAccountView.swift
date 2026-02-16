//
//  LocalAccountView.swift
//
//
//  Created by Codex on 2026/2/8.
//

import SwiftUI
import Models

public struct LocalAccountView: View {
    @State private var user: User? = nil
    @State private var isExporting = false
    @State private var exportProgress: LocalMemoExportProgress?
    @State private var exportErrorMessage: String?
    @State private var exportedZipURL: URL?
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

            if accountKey == accountManager.currentAccount?.key {
                Section {
                    Button {
                        startExport()
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("account.local-export-button")
                        }
                    }
                    .disabled(isExporting)

                    if let progress = exportProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: progress.fractionCompleted)
                            Text(progress.message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if let exportedZipURL {
                        ShareLink(item: exportedZipURL) {
                            Label("account.local-export-share-zip", systemImage: "square.and.arrow.up")
                        }
                        Text(exportedZipURL.lastPathComponent)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let exportErrorMessage {
                        Text(exportErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("account.local-export")
                }
            }

            Section {
                Text("account.local-account-cannot-be-removed")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("account.account-detail")
        .task {
            guard let account = account else { return }
            if let cached = accountViewModel.users.first(where: { $0.accountKey == accountKey }) {
                user = cached
            } else {
                user = try? await account.toUser()
            }
        }
    }

    private func startExport() {
        guard !isExporting else { return }
        guard let localService = accountManager.service(for: accountKey) as? LocalService else {
            exportErrorMessage = NSLocalizedString("account.local-export-error-not-available", comment: "Local export unavailable for non-local account")
            exportProgress = nil
            return
        }

        let snapshots = localService.exportSnapshots()
        guard !snapshots.isEmpty else {
            exportErrorMessage = NSLocalizedString("account.local-export-error-empty", comment: "No local memos to export")
            exportProgress = nil
            exportedZipURL = nil
            return
        }

        isExporting = true
        exportErrorMessage = nil
        exportedZipURL = nil
        exportProgress = .init(
            completed: 0,
            total: 1,
            message: NSLocalizedString("account.local-export-progress-preparing", comment: "Preparing local export")
        )

        Task { @MainActor in
            defer { isExporting = false }
            do {
                let zipURL = try await LocalMemoExporter.export(snapshots: snapshots) { progress in
                    await MainActor.run {
                        exportProgress = progress
                    }
                }
                exportedZipURL = zipURL
            } catch {
                exportProgress = nil
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}
