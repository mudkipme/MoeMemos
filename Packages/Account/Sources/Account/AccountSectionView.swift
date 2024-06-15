//
//  AccountSectionView.swift
//
//
//  Created by Mudkip on 2023/11/25.
//

import SwiftUI
import Env

public struct AccountSectionView: View {
    @Environment(AccountViewModel.self) private var accountViewModel
    @Environment(AccountManager.self) private var accountManager
    
    public init() {}
    
    public var body: some View {
        Section {
            ForEach(accountViewModel.users) { user in
                NavigationLink(value: Route.memosAccount(user.accountKey)) {
                    Label(title: {
                        if user.accountKey == accountManager.currentAccount?.key {
                            Text(user.nickname)
                                .bold()
                        } else {
                            Text(user.nickname)
                        }
                    }) {
                        if let avatarData = user.avatarData, let uiImage = UIImage(data: avatarData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(Circle())
                        } else {
                            Image(.memos)
                                .resizable()
                                .scaledToFit()
                                .clipShape(Circle())
                        }
                    }
                }
            }
            Button {
                accountViewModel.showingAddAccount = true
            } label: {
                Label("account.add-account", systemImage: "plus.circle")
            }
        } header: {
            Text("account.accounts")
        }
    }
}
