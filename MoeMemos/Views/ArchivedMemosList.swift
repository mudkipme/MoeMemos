//
//  ArchivedMemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/6.
//

import SwiftUI
import Models

struct ArchivedMemosList: View {
    @State private var viewModel = ArchivedMemoListViewModel()
    @State private var searchString = ""

    var body: some View {
        let filteredMemoList = filterMemoList(viewModel.archivedMemoList)
        List(filteredMemoList, id: \.id) { memo in
            Section {
                ArchivedMemoCard(memo, archivedViewModel: viewModel)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("memo.archived")
        .task {
            do {
                try await viewModel.loadArchivedMemos()
            } catch {
                print(error)
            }
        }
        .refreshable {
            do {
                try await viewModel.loadArchivedMemos()
            } catch {
                print(error)
            }
        }
        .searchable(text: $searchString)
    }
    
    private func filterMemoList(_ memoList: [StoredMemo]) -> [StoredMemo] {
        var memoList = memoList
        if !searchString.isEmpty {
            memoList = memoList.filter({ memo in
                memo.content.localizedCaseInsensitiveContains(searchString)
            })
        }
        
        return memoList
    }
}

struct ArchivedMemosList_Previews: PreviewProvider {
    static var previews: some View {
        ArchivedMemosList()
    }
}
