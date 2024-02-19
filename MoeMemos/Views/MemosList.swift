//
//  MemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import MemosService
import Account
import Models

struct MemosList: View {
    let tag: Tag?

    @State private var searchString = ""
    @State private var showingNewPost = false
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Environment(AccountViewModel.self) var userState: AccountViewModel
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var filteredMemoList: [MemosMemo] = []
    
    var body: some View {
        let defaultMemoVisibility = userState.currentUser?.defaultVisibility ?? .private
        
        ZStack(alignment: .bottomTrailing) {
            List(filteredMemoList, id: \.id) { memo in
                Section {
                    MemoCard(memo, defaultMemoVisibility: defaultMemoVisibility)
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            if tag == nil {
                Button {
                    showingNewPost = true
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
        .overlay(content: {
            if memosViewModel.loading && !memosViewModel.inited {
                ProgressView()
            }
        })
        .searchable(text: $searchString)
        .navigationTitle(tag?.name ?? NSLocalizedString("memo.memos", comment: "Memos"))
        .sheet(isPresented: $showingNewPost) {
            MemoInput(memo: nil)
        }
        .onAppear {
            filteredMemoList = filterMemoList(memosViewModel.memoList, tag: tag, searchString: searchString)
        }
        .refreshable {
            do {
                try await memosViewModel.loadMemos()
            } catch {
                print(error)
            }
        }
        .task(id: accountManager.currentAccount, {
            do {
                try await memosViewModel.loadMemos()
            } catch {
                print(error)
            }
        })
        .onChange(of: memosViewModel.memoList) { _, newValue in
            filteredMemoList = filterMemoList(newValue, tag: tag, searchString: searchString)
        }
        .onChange(of: tag) { _, newValue in
            filteredMemoList = filterMemoList(memosViewModel.memoList, tag: newValue, searchString: searchString)
        }
        .onChange(of: searchString) { _, newValue in
            filteredMemoList = filterMemoList(memosViewModel.memoList, tag: tag, searchString: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                if memosViewModel.inited {
                    try await memosViewModel.loadMemos()
                }
            }
        }
    }
    
    private func filterMemoList(_ memoList: [MemosMemo], tag: Tag?, searchString: String) -> [MemosMemo] {
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
