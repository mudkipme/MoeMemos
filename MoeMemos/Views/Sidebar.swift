//
//  Sidebar.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

fileprivate let weekDaySymbols = Calendar.current.shortWeekdaySymbols

struct Sidebar: View {
    @State private var toMemosList = true
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @EnvironmentObject private var userState: UserState
    @Binding var selection: Route?

    var body: some View {
        List(selection: UIDevice.current.userInterfaceIdiom == .pad ? $selection : nil) {
            VStack {
                Stats()
                    .padding(20)
                
                HStack {
                    VStack(alignment: .trailing) {
                        Text(weekDaySymbols.first ?? "")
                            .font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                        Text(weekDaySymbols[weekDaySymbols.count / 2])
                            .font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                        Text(weekDaySymbols.last ?? "")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Heatmap(matrix: memosViewModel.matrix)
                }
                .frame(minHeight: 120, maxHeight: 120)
                .padding(.bottom, 10)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(EmptyView())
            
            Section {
                if #available(iOS 16, *) {
                    NavigationLink(value: Route.memos) {
                        Label("memo.memos", systemImage: "rectangle.grid.1x2")
                    }
                } else {
                    NavigationLink(destination: MemosList(tag: nil), isActive: $toMemosList) {
                        Label("memo.memos", systemImage: "rectangle.grid.1x2")
                    }
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
                }
            } header: {
                Text("tags")
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            if #available(iOS 16, *), UIDevice.current.userInterfaceIdiom == .pad {
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
