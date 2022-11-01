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
                    Heatmap()
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
                        Label("Memos", systemImage: "rectangle.grid.1x2")
                    }
                } else {
                    NavigationLink(destination: MemosList(tag: nil), isActive: $toMemosList) {
                        Label("Memos", systemImage: "rectangle.grid.1x2")
                    }
                }
                NavLink(route: .resources) {
                    Label("Resources", systemImage: "photo.on.rectangle")
                }
                NavLink(route: .archived) {
                    Label("Archived", systemImage: "archivebox")
                }
            } header: {
                Text("Moe Memos")
            }
            
            Section {
                ForEach(memosViewModel.tags) { tag in
                    NavLink(route: .tag(tag)) {
                        Label(tag.name, systemImage: "number")
                    }
                }
            } header: {
                Text("Tags")
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
        .navigationTitle(userState.currentUser?.name ?? "Memos")
        .task {
            do {
                try await memosViewModel.loadTags()
            } catch {
                print(error)
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
