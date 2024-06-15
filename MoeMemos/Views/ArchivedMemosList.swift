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
    @State private var filteredMemoList: [Memo] = []

    var body: some View {
        List(filteredMemoList, id: \.remoteId) { memo in
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
        .onAppear {
            filteredMemoList = filterMemoList(viewModel.archivedMemoList)
        }
        .onChange(of: viewModel.archivedMemoList) { _, newValue in
            filteredMemoList = filterMemoList(newValue)
        }
        .onChange(of: searchString) { _, newValue in
            filteredMemoList = filterMemoList(viewModel.archivedMemoList)
        }
    }
    
    private func filterMemoList(_ memoList: [Memo]) -> [Memo] {
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
