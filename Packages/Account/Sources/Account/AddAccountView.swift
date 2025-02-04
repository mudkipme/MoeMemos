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
    @State private var path: [AddAccountRouter] = []
    
    public init() {}
    
    public var body: some View {
        NavigationStack(path: $path) {
            List {
//                HStack {
//                    Image(systemName: "house")
//                    VStack(alignment: .leading) {
//                        Text("Add a Local Account")
//                            .foregroundStyle(.primary)
//                            .font(.headline)
//                        Text("On this Device")
//                            .font(.subheadline)
//                            .foregroundStyle(.secondary)
//                    }
//                }
//                .onTapGesture {
//                    try? accountManager.add(account: .local)
//                    dismiss()
//                }
                
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
                
                NavigationLink(value: AddAccountRouter.addBlinkoAccount) {
                    HStack {
                        Image(systemName: "face.smiling")
                        VStack(alignment: .leading) {
                            Text("account.add-blinko-account")
                                .foregroundStyle(.primary)
                                .font(.headline)
                            Text("account.blinko-account-description")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                if !accountManager.accounts.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("input.close") {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(accountManager.accounts.isEmpty ? NSLocalizedString("moe-memos", comment: "") : NSLocalizedString("account.add-account", comment: ""))
            .navigationDestination(for: AddAccountRouter.self) { router in
                switch router {
                case .addMemosAccount:
                    AddMemosAccountView(dismiss: dismiss)
                case .addBlinkoAccount:
                    AddBlinkoAccountView(dismiss: dismiss)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
