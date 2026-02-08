//
//  AccountDetailView.swift
//
//
//  Created by Codex on 2026/2/8.
//

import SwiftUI
import Models

public struct AccountDetailView: View {
    private let accountKey: String
    @Environment(AccountManager.self) private var accountManager

    public init(accountKey: String) {
        self.accountKey = accountKey
    }

    public var body: some View {
        if isLocalAccount {
            LocalAccountView(accountKey: accountKey)
        } else {
            MemosAccountView(accountKey: accountKey)
        }
    }

    private var isLocalAccount: Bool {
        guard let account = accountManager.accounts.first(where: { $0.key == accountKey }) else {
            return accountKey == "local"
        }
        if case .local = account {
            return true
        }
        return false
    }
}
