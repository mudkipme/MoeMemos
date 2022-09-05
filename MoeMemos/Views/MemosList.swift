//
//  MemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct MemosList: View {
    @State private var searchString = ""
    @State private var showingNewPost = false
    @EnvironmentObject private var memosViewModel: MemosViewModel
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List(memosViewModel.memoList, id: \.id) { memo in
                Section {
                    MemoCard(memo)
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            Button {
                showingNewPost = true
            } label: {
                Circle().overlay {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundColor(.white)
                }
                .frame(width: 60, height: 60)
            }.padding(20)
        }
        .searchable(text: $searchString)
        .navigationTitle("Memos")
        .sheet(isPresented: $showingNewPost) {
            MemoInput()
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
    }
}

struct MemosList_Previews: PreviewProvider {
    static var previews: some View {
        MemosList()
    }
}
