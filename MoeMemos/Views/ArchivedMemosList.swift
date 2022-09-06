//
//  ArchivedMemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/6.
//

import SwiftUI

struct ArchivedMemosList: View {
    @EnvironmentObject private var memosViewModel: MemosViewModel

    var body: some View {
        List(memosViewModel.archivedMemoList, id: \.id) { memo in
            Section {
                MemoCard(memo)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Archived")
        .task {
            do {
                try await memosViewModel.loadArchivedMemos()
            } catch {
                print(error)
            }
        }
        .refreshable {
            do {
                try await memosViewModel.loadArchivedMemos()
            } catch {
                print(error)
            }
        }
    }
}

struct ArchivedMemosList_Previews: PreviewProvider {
    static var previews: some View {
        ArchivedMemosList()
            .environmentObject(MemosViewModel())
    }
}
