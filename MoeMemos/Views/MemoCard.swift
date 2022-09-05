//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct MemoCard: View {
    let memo: Memo
    
    init(_ memo: Memo) {
        self.memo = memo
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .bottom) {
                Text(renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                
                Menu {
                    Button {
                        
                    } label: {
                        Label("Pin", systemImage: "flag")
                    }
                    Button {
                        
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive, action: {
                        
                    }, label: {
                        Label("Archive", systemImage: "archivebox")
                    })
                } label: {
                    Image(systemName: "ellipsis").frame(minHeight: 20)
                }
            }
            
            Text(renderContent())
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contextMenu {
            Button {
                
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .padding([.top, .bottom], 5)
    }
    
    private func renderTime() -> String {
        if Calendar.current.dateComponents([.day], from: memo.createdTs, to: .now).day! > 7 {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            return formatter.string(from: memo.createdTs)
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: memo.createdTs, relativeTo: .now)
    }
    
    private func renderContent() -> AttributedString {
        do {
            return try AttributedString(markdown: memo.content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            return AttributedString(memo.content)
        }
    }
}

struct MemoCard_Previews: PreviewProvider {
    static var previews: some View {
        MemoCard(Memo.samples[0])
    }
}
