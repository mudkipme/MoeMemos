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
            .padding(10)
            
            List {
                NavigationLink(destination: MemosList(), isActive: $toMemosList) {
                    Text("✍️ Memos")
                }
                NavigationLink(destination: {
                    
                }) {
                    Text("🗂 Archived")
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
            
            Spacer()
            
            Text("Moe Memos")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        Sidebar()
    }
}
