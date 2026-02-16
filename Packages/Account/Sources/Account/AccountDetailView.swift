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
        accountKey == Account.local.key
    }
}
