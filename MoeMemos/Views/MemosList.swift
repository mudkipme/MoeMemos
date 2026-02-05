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
import SwiftData

struct MemosList: View {
    let tag: Tag?

    @State private var searchString = ""
    @Environment(AppPath.self) private var appPath
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Environment(AccountViewModel.self) var userState: AccountViewModel
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    
    var body: some View {
        let defaultMemoVisibility = userState.currentUser?.defaultVisibility ?? .private
        let filteredMemoList = filterMemoList(memosViewModel.memoList, tag: tag, searchString: searchString)
        
        ZStack(alignment: .bottomTrailing) {
            List(filteredMemoList, id: \.id) { item in
                Section {
                    MemoCard(item, defaultMemoVisibility: defaultMemoVisibility)
                }
            }
            .listStyle(InsetGroupedListStyle())
            
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
        .overlay(content: {
            if memosViewModel.loading && !memosViewModel.inited {
                ProgressView()
            }
        })
        .searchable(text: $searchString)
        .navigationTitle(tag?.name ?? NSLocalizedString("memo.memos", comment: "Memos"))
        .refreshable {
            do {
                try await memosViewModel.loadMemos()
            } catch {
                print(error)
            }
        }
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
                memo.content.contains("#\(tag.name) ") || memo.content.contains("#\(tag.name)/")
                || memo.content.contains("#\(tag.name)\n")
                || memo.content.hasSuffix("#\(tag.name)")
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
