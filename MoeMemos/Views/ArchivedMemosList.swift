//
//  ArchivedMemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/6.
//

import SwiftUI
import Account
import Models
import DesignSystem

struct ArchivedMemosList: View {
    @State private var viewModel = ArchivedMemoListViewModel()
    @State private var searchString = ""
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @State private var manualSyncError: Error?
    @State private var showingSyncErrorToast = false

    var body: some View {
        let filteredMemoList = filterMemoList(viewModel.archivedMemoList)
        let unsyncedCount = memosViewModel.memoList.filter { $0.syncState != .synced }.count
        let canSync = ((try? memosViewModel.service) as? SyncableService) != nil

        Group {
            if filteredMemoList.isEmpty {
                ContentUnavailableView("memo.archived.empty", systemImage: "archivebox")
            } else {
                List(filteredMemoList, id: \.id) { memo in
                    Section {
                        ArchivedMemoCard(memo, archivedViewModel: viewModel)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("memo.archived")
        .toolbar {
            if canSync {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusBadge(syncing: memosViewModel.syncing, unsyncedCount: unsyncedCount) {
                        Task {
                            do {
                                try await memosViewModel.syncNow()
                                try await viewModel.reloadArchivedMemos()
                            } catch {
                                manualSyncError = error
                                showingSyncErrorToast = true
                            }
                        }
                    }
                }
            }
            if #available(iOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
        }
        .task {
            do {
                try await viewModel.loadArchivedMemos()
            } catch {
                print(error)
            }
        }
        .searchable(text: $searchString)
        .toast(isPresenting: $showingSyncErrorToast, alertType: .systemImage("xmark.circle", manualSyncError?.localizedDescription))
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
