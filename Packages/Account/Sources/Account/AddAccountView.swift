//
//  AddAccountView.swift
//
//
//  Created by Mudkip on 2023/11/25.
//

import SwiftUI

public struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Environment(AccountViewModel.self) private var accountViewModel: AccountViewModel
    @State private var path: [AddAccountRouter] = []
    
    public init() {}
    
    public var body: some View {
        let hasLocalAccount = accountManager.accounts.contains { account in
            if case .local = account {
                return true
            }
            return false
        }

        NavigationStack(path: $path) {
            List {
                if !hasLocalAccount {
                    Button {
                        Task {
                            try? accountManager.add(account: .local)
                            try? await accountViewModel.reloadUsers()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "house")
                            VStack(alignment: .leading) {
                                Text("account.add-local-account")
                                    .foregroundStyle(.primary)
                                    .font(.headline)
                                Text("account.local-account-description")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                NavigationLink(value: AddAccountRouter.addMemosAccount) {
                    HStack {
                        Image(systemName: "pencil")
                        VStack(alignment: .leading) {
                            Text("account.add-memos-account")
                                .foregroundStyle(.primary)
                                .font(.headline)
                            Text("account.memos-account-description")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                if !accountManager.accounts.isEmpty && !accountViewModel.users.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("input.close") {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle((accountManager.accounts.isEmpty || accountViewModel.users.isEmpty) ? NSLocalizedString("moe-memos", comment: "") : NSLocalizedString("account.add-account", comment: ""))
            .navigationDestination(for: AddAccountRouter.self) { router in
                switch router {
                case .addMemosAccount:
                    AddMemosAccountView(dismiss: dismiss)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
