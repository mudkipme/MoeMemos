//
//  Sidebar.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import Account

struct Sidebar: View {
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Environment(AccountViewModel.self) private var userState: AccountViewModel
    @Binding var selection: Route?

    var body: some View {
        List(selection: UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .vision ? $selection : nil) {
            Stats()
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(EmptyView())
            
            Section {
                NavigationLink(value: Route.memos) {
                    Label("memo.memos", systemImage: "rectangle.grid.1x2")
                }
                NavigationLink(value: Route.explore) {
                    Label("explore", systemImage: "house")
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
                ForEach(memosViewModel.tags) { tag in
                    NavigationLink(value: Route.tag(tag)) {
                        Label(tag.name, systemImage: "number")
                    }
                }.onDelete { indexSet in
                    let toDeleteTags = indexSet.map { memosViewModel.tags[$0].name }
                    Task {
                        for tag in toDeleteTags {
                            try await memosViewModel.deleteTag(name: tag)
                        }
                    }
                }
            } header: {
                Text("tags")
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .vision {
                Button(action: {
                    selection = .settings
                }) {
                    Image(systemName: "ellipsis.circle")
                }
            } else {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationTitle(userState.currentUser?.nickname ?? NSLocalizedString("memo.memos", comment: "Memos"))
    }
}
