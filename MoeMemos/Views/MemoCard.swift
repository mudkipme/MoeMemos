//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter
}()


struct MemoCard: View {
    let memo: Memo
    
    init(_ memo: Memo) {
        self.memo = memo
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                Text(relativeFormatter.localizedString(for: memo.createdTs, relativeTo: .now))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    
                } label: {
                    Image(systemName: "ellipsis").frame(minHeight: 20)
                }
                .buttonStyle(.borderless)
            }
            
            Text(memo.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.padding([.top, .bottom], 5)
 
    }
}

struct MemoCard_Previews: PreviewProvider {
    static var previews: some View {
        MemoCard(Memo.samples[0])
    }
}
