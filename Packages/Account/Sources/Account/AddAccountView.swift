//
//  AddAccountView.swift
//
//
//  Created by Mudkip on 2023/11/25.
//

import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AccountManager.self) var accountManager: AccountManager
    
    var body: some View {
        NavigationStack {
            List {
                HStack {
                    Image(systemName: "house")
                    VStack(alignment: .leading) {
                        Text("Add a Local Account")
                            .foregroundStyle(.primary)
                            .font(.headline)
                        Text("On this Device")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .onTapGesture {
                    try? accountManager.add(account: .local)
                    dismiss()
                }
                
                NavigationLink(value: "login") {
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
        }
    }
}

#Preview {
    AddAccountView()
}
