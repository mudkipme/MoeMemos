//
//  AddAccountView.swift
//
//
//  Created by Mudkip on 2023/11/25.
//

import SwiftUI
import Models

public struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountViewModel.self) private var accountViewModel: AccountViewModel
    @State private var path: [AddAccountRouter] = []
    
    public init() {}
    
    public var body: some View {
        let hasLocalAccount = accountViewModel.users.contains { $0.accountKey == Account.local.key }
        let hasAnyAccount = !accountViewModel.users.isEmpty

        NavigationStack(path: $path) {
            List {
                if !hasLocalAccount {
                    Button {
                        Task {
                            try? await accountViewModel.loginLocal()
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
                if hasAnyAccount {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("input.close") {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(hasAnyAccount ? NSLocalizedString("account.add-account", comment: "") : NSLocalizedString("moe-memos", comment: ""))
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
