//
//  MemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct MemosList: View {
    let tag: Tag?

    @State private var searchString = ""
    @State private var showingNewPost = false
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var filteredMemoList: [Memo] = []
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List(filteredMemoList, id: \.id) { memo in
                Section {
                    MemoCard(memo)
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            if memosViewModel.currentUser != nil && tag == nil {
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
        .navigationTitle(tag?.name ?? "Memos")
        .sheet(isPresented: $showingNewPost) {
            MemoInput(memo: nil)
        }
        .onAppear {
            filteredMemoList = filterMemoList(memosViewModel.memoList)
        }
        .refreshable {
            do {
                try await memosViewModel.loadMemos()
            } catch {
                print(error)
            }
        }
        .task {
            do {
                try await memosViewModel.loadMemos()
            } catch {
                print(error)
            }
        }
        .onChange(of: memosViewModel.memoList, perform: { newValue in
            filteredMemoList = filterMemoList(newValue)
        })
        .onChange(of: searchString, perform: { newValue in
            filteredMemoList = filterMemoList(memosViewModel.memoList)
        })
    }
    
    private func filterMemoList(_ memoList: [Memo]) -> [Memo] {
        let pinned = memoList.filter { $0.pinned }
        let nonPinned = memoList.filter { !$0.pinned }
        var fullList = pinned + nonPinned
        
        if let tag = tag {
            fullList = fullList.filter({ memo in
                memo.content.contains("#\(tag.name) ") || memo.content.contains("#\(tag.name)/")
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

struct MemosList_Previews: PreviewProvider {
    static var previews: some View {
        MemosList(tag: nil)
            .environmentObject(MemosViewModel())
    }
}
