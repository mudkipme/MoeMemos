//
//  MemosList.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct MemosList: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List(Memo.samples, id: \.id) { memo in
                Section {
                    MemoCard(memo)
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            ZStack {
                Button {
                    
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                }
            }.padding(20)
        }
        .navigationTitle("Memos")
    }
}

struct MemosList_Previews: PreviewProvider {
    static var previews: some View {
        MemosList()
    }
}
