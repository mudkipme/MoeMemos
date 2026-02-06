//
//  MemosAccountView.swift
//
//
//  Created by Mudkip on 2024/6/15.
//

import Foundation
import SwiftUI
import Models
import Env
import DesignSystem

public struct MemosAccountView: View {
    @State var user: User? = nil
    @State var version: MemosVersion? = nil
    @State private var pendingUnsyncedMemoCount = 0
    @State private var showingUnsyncedDeleteConfirmation = false
    @State private var deleteError: Error?
    @State private var showingDeleteErrorToast = false
    private let accountKey: String
    @Environment(AccountManager.self) private var accountManager
    @Environment(AccountViewModel.self) private var accountViewModel
    @Environment(AppPath.self) private var appPath
    private var account: Account? { accountManager.accounts.first { $0.key == accountKey } }
    @Environment(\.presentationMode) var presentationMode
    
    public init(accountKey: String) {
        self.accountKey = accountKey
    }
    
    public var body: some View {
        List {
            if let user = user {
                VStack(alignment: .leading) {
                    if let avatarData = user.avatarData, let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    }
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
            
            if let version = version?.version {
                Label(title: { Text("memos v\(version)").foregroundStyle(.secondary) }) {
                    Image(.memos)
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                }
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
            
            if isLocalAccount {
                Section {
                    Text("Local account cannot be removed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Button(role: .destructive) {
                        requestDeleteAccount()
                    } label: {
                        HStack {
                            Spacer()
                            Text("settings.sign-out")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("account.account-detail")
        .alert("Delete account?", isPresented: $showingUnsyncedDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete account", role: .destructive) {
                Task {
                    await performDeleteAccount()
                }
            }
        } message: {
            Text("This account has \(pendingUnsyncedMemoCount) unsynced memo(s). Deleting the account will remove all local data for this account and these memo changes will be lost.")
        }
        .toast(isPresenting: $showingDeleteErrorToast, alertType: .systemImage("xmark.circle", deleteError?.localizedDescription))
        .task {
            guard let account = account else { return }
            if let cached = accountViewModel.users.first(where: { $0.accountKey == accountKey }) {
                user = cached
            } else {
                user = try? await account.toUser()
            }
        }
        .task {
            guard let account = account else { return }
            
            var hostURL: URL?
            switch account {
            case .memosV0(host: let host, id: _, accessToken: _):
                hostURL = URL(string: host)
            case .memosV1(host: let host, id: _, accessToken: _):
                hostURL = URL(string: host)
            case .local:
                return
            }
            guard let hostURL = hostURL else { return }
            version = try? await detectMemosVersion(hostURL: hostURL)
        }
    }

    private var isLocalAccount: Bool {
        guard let account else { return false }
        if case .local = account {
            return true
        }
        return false
    }

    private func requestDeleteAccount() {
        guard let account else { return }
        let unsyncedCount = accountManager.unsyncedMemoCount(for: account.key)
        if unsyncedCount > 0 {
            pendingUnsyncedMemoCount = unsyncedCount
            showingUnsyncedDeleteConfirmation = true
            return
        }
        Task {
            await performDeleteAccount()
        }
    }

    private func performDeleteAccount() async {
        guard let account else { return }
        do {
            try await accountViewModel.logout(account: account)
            presentationMode.wrappedValue.dismiss()
            if accountManager.currentAccount == nil {
                appPath.presentedSheet = .addAccount
            }
        } catch {
            deleteError = error
            showingDeleteErrorToast = true
        }
    }
}
