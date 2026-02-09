//
//  MemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import Account
import Models
import Env
import DesignSystem

struct MemosList: View {
    let tag: Tag?

    @State private var searchString = ""
    @Environment(AppPath.self) private var appPath
    @Environment(AccountViewModel.self) var userState: AccountViewModel
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @State private var manualSyncError: Error?
    @State private var showingSyncErrorToast = false
    
    var body: some View {
        let defaultMemoVisibility = userState.currentUser?.defaultVisibility ?? .private
        let filteredMemoList = filterMemoList(memosViewModel.memoList, tag: tag, searchString: searchString)
        let unsyncedCount = memosViewModel.memoList.filter { $0.syncState != .synced }.count
        let canSync = ((try? memosViewModel.service) as? SyncableService) != nil
        
        ZStack(alignment: .bottomTrailing) {
            if filteredMemoList.isEmpty {
                ContentUnavailableView("memo.memos.empty", systemImage: "note.text")
            } else {
                List(filteredMemoList, id: \.id) { item in
                    Section {
                        NavigationLink(value: Route.memo(item.id)) {
                            MemoCard(item, defaultMemoVisibility: defaultMemoVisibility)
                            }
                            .navigationLinkIndicatorVisibility(.hidden)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            
            if #unavailable(iOS 26.0) {
                Button {
                    appPath.presentedSheet = .newMemo
                } label: {
                    Circle().overlay {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.white)
                    }
                    .shadow(radius: 1)
                    .frame(width: 60, height: 60)
                }
                .padding(20)
            }
        }
        .toolbar {
            if canSync {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStatusBadge(syncing: memosViewModel.syncing, unsyncedCount: unsyncedCount) {
                        Task {
                            do {
                                try await memosViewModel.syncNow()
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
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        appPath.presentedSheet = .newMemo
                    } label: {
                        Label("input.save", systemImage: "plus")
                    }
                }
            }
        }
        .searchable(text: $searchString)
        .navigationTitle(tag?.name ?? NSLocalizedString("memo.memos", comment: "Memos"))
        .toast(isPresenting: $showingSyncErrorToast, alertType: .systemImage("xmark.circle", manualSyncError?.localizedDescription))
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                if memosViewModel.inited {
                    try await memosViewModel.loadMemos()
                }
            }
        }
    }
    
    private func filterMemoList(_ memoList: [StoredMemo], tag: Tag?, searchString: String) -> [StoredMemo] {
        let pinned = memoList.filter { $0.pinned == true }
        let nonPinned = memoList.filter { !($0.pinned == true) }
        var fullList = pinned + nonPinned
        
        if let tag = tag {
            fullList = fullList.filter({ memo in
                MemoTagExtractor.extract(from: memo.content).contains(tag.name)
            })
        }
        
        if !searchString.isEmpty {
            fullList = fullList.filter({ memo in
                memo.content.localizedCaseInsensitiveContains(searchString)
            })
        }
        
        return fullList
    }
}
