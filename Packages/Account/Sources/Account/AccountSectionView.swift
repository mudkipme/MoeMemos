//
//  AccountSectionView.swift
//
//
//  Created by Mudkip on 2023/11/25.
//

import SwiftUI

public struct AccountSectionView: View {
    @Environment(AccountViewModel.self) var accountViewModel: AccountViewModel
    @State var showingAddAccount = false
    
    public init() {}
    
    public var body: some View {
        Section {
            ForEach(accountViewModel.users) { user in
                if let avatarData = user.avatarData, let uiImage = UIImage(data: avatarData) {
                    Label(title: { Text(user.nickname) }) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(Circle())
                    }
                } else {
                    Text(user.nickname)
                }
            }
            Button {
                showingAddAccount = true
            } label: {
                Label("account.add-account", systemImage: "plus.circle")
            }
        } header: {
            Text("Accounts")
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView()
        }
    }
}
