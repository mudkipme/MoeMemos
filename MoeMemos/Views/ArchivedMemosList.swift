//
//  ArchivedMemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/6.
//

import SwiftUI
import Account
import Models

struct ArchivedMemosList: View {
    @State private var viewModel = ArchivedMemoListViewModel()
    @State private var searchString = ""
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @State private var manualSyncAlertMessage: String?
    @State private var showingManualSyncAlert = false
    @State private var showingHigherV1SyncConfirmation = false

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
                        triggerManualSync()
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
        .alert(NSLocalizedString("sync.failed.title", comment: "Manual sync failed alert title"), isPresented: $showingManualSyncAlert) {
            Button(NSLocalizedString("common.ok", comment: "OK button label"), role: .cancel) {}
        } message: {
            Text(manualSyncAlertMessage ?? NSLocalizedString("Unknown error.", comment: ""))
        }
        .confirmationDialog(NSLocalizedString("compat.continue-sync.title", comment: "Higher version sync confirmation title"), isPresented: $showingHigherV1SyncConfirmation, titleVisibility: .visible) {
            Button(NSLocalizedString("common.cancel", comment: "Cancel button label"), role: .cancel) {}
            Button(NSLocalizedString("compat.action.still-sync", comment: "Force sync button label")) {
                triggerManualSync(forceHigherV1VersionSync: true)
            }
        } message: {
            Text(manualSyncAlertMessage ?? moeMemosHigherMemosVersionSyncWarning)
        }
    }

    private func triggerManualSync(forceHigherV1VersionSync: Bool = false) {
        Task {
            do {
                try await memosViewModel.syncNow(trigger: .manual, forceHigherV1VersionSync: forceHigherV1VersionSync)
                try await viewModel.reloadArchivedMemos()
            } catch let error as ManualSyncCompatibilityError {
                switch error {
                case .unsupportedVersion:
                    manualSyncAlertMessage = error.localizedDescription
                    showingManualSyncAlert = true
                case .higherV1VersionNeedsConfirmation(version: _):
                    manualSyncAlertMessage = error.localizedDescription
                    showingHigherV1SyncConfirmation = true
                }
            } catch {
                manualSyncAlertMessage = error.localizedDescription
                showingManualSyncAlert = true
            }
        }
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
