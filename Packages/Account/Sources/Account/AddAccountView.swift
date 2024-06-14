//
//  AddAccountView.swift
//
//
//  Created by Mudkip on 2023/11/25.
//

import SwiftUI

public struct AddAccountView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AccountManager.self) var accountManager: AccountManager
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
                            Text("Add a Memos Account")
                                .foregroundStyle(.primary)
                                .font(.headline)
                            Text("Sync with Your Memos Server")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Add Accounts")
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
