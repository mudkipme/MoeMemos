//
//  Sidebar.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import Account
import Env
import Models

struct Sidebar: View {
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Environment(AccountViewModel.self) private var userState: AccountViewModel
    @Binding var selection: Route?

    var body: some View {
        let isLocalAccount = accountManager.currentAccount.map { account in
            if case .local = account {
                return true
            }
            return false
        } ?? false

        List(selection: $selection) {
            Stats()
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(EmptyView())
            
            Section {
                NavigationLink(value: Route.memos) {
                    Label("memo.memos", systemImage: "rectangle.grid.1x2")
                }
                if !isLocalAccount {
                    NavigationLink(value: Route.explore) {
                        Label("explore", systemImage: "house")
                    }
                }
                NavigationLink(value: Route.resources) {
                    Label("resources", systemImage: "photo.on.rectangle")
                }
                NavigationLink(value: Route.archived) {
                    Label("memo.archived", systemImage: "archivebox")
                }
            } header: {
                Text("moe-memos")
            }
            
            Section {
                OutlineGroup(memosViewModel.nestedTags, children: \.children) { item in
                    NavigationLink(value: Route.tag(Tag(name: item.fullName))) {
                        Label(item.name, systemImage: "number")
                    }
                }
            } header: {
                Text("tags")
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            Button(action: {
                selection = .settings
            }) {
                Image(systemName: "ellipsis")
            }
        }
        .navigationTitle(userState.currentUser?.nickname ?? NSLocalizedString("memo.memos", comment: "Memos"))
    }
}
