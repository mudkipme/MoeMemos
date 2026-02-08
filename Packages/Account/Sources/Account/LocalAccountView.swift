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
    private let accountKey: String
    @Environment(AccountManager.self) private var accountManager
    @Environment(AccountViewModel.self) private var accountViewModel
    @Environment(\.presentationMode) var presentationMode
    private var account: Account? { accountManager.accounts.first { $0.key == accountKey } }

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
}
