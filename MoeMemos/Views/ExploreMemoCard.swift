//
//  ExploreMemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
import Models

struct ExploreMemoCard: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(memo.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if let creatorName = memo.user?.nickname {
                    Text("@\(creatorName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 5)
            
            MemoCardContent(memo: memo)
        }
        .padding([.top, .bottom], 5)
    }
}
