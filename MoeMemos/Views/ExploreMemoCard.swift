//
//  ExploreMemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
import MemosV0Service

struct ExploreMemoCard: View {
    let memo: MemosMemo

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
        ExploreMemoCard(memo: MemosMemo(content: "Hello world\n\nThis is a **multiline** statement and thank you for everything.", createdTs: Int(Date.now.addingTimeInterval(-100).timeIntervalSince1970), id: 1))
    }
}
