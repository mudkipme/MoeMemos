//
//  Sidebar.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @EnvironmentObject private var userState: UserState
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
                NavLink(route: .explore) {
                    Label("explore", systemImage: "house")
                }
                NavLink(route: .resources) {
                    Label("resources", systemImage: "photo.on.rectangle")
                }
                NavLink(route: .archived) {
                    Label("memo.archived", systemImage: "archivebox")
                }
            } header: {
                Text("moe-memos")
            }
            
            Section {
                ForEach(memosViewModel.tags) { tag in
                    NavLink(route: .tag(tag)) {
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
                NavLink(route: .settings) {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationTitle(userState.currentUser?.displayName ?? NSLocalizedString("memo.memos", comment: "Memos"))
        .task {
            do {
                try await memosViewModel.loadTags()
            } catch {
                print(error)
            }
        }
        .onChange(of: userState.currentUser?.id) { newValue in
            Task {
                try await memosViewModel.loadTags()
            }
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    @State static var route: Route? = .memos

    static var previews: some View {
        Sidebar(selection: $route)
            .environmentObject(MemosViewModel())
            .environmentObject(UserState())
    }
}
