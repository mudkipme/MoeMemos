//
//  ExploreMemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI

struct ExploreMemoCard: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(memo.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if let creatorName = memo.creatorName {
                    Text("@\(creatorName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 5)
            
            MemoCardContent(memo: memo, toggleTaskItem: nil)
        }
        .padding([.top, .bottom], 5)
    }

}

struct ExploreMemoCard_Previews: PreviewProvider {
    static var previews: some View {
        ExploreMemoCard(memo: Memo(id: 1, createdTs: .now.addingTimeInterval(-100), creatorId: 1, creatorName: nil, content: "Hello world\n\nThis is a **multiline** statement and thank you for everything.", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: .private, resourceList: nil))
    }
}
