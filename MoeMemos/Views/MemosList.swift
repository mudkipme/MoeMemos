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
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List(Memo.samples, id: \.id) { memo in
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
    }
}

struct MemosList_Previews: PreviewProvider {
    static var previews: some View {
        MemosList()
    }
}
