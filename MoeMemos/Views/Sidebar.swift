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

    var body: some View {
        List {
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
                NavigationLink(destination: MemosList(), isActive: $toMemosList) {
                    Label("Memos", systemImage: "rectangle.grid.1x2")
                }
                NavigationLink(destination: {
                    
                }) {
                    Label("Archived", systemImage: "archivebox")
                }
            } header: {
                Text("Moe Memos")
            }
            
            Section {
                NavigationLink(destination: {}) {
                    Label("Games", systemImage: "number")
                }
            } header: {
                Text("Tags")
            }
        }
        .listStyle(.sidebar)
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        Sidebar()
    }
}
