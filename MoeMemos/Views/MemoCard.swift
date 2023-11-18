//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI
import MemosService

struct MemoCard: View {
    let memo: MemosMemo
    let defaultMemoVisilibity: MemosVisibility?
    
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var showingEdit = false
    
    init(_ memo: MemosMemo, defaultMemoVisibility: MemosVisibility) {
        self.memo = memo
        self.defaultMemoVisilibity = defaultMemoVisibility
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(memo.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if defaultMemoVisilibity != nil && memo.visibility != defaultMemoVisilibity, let visibility = memo.visibility {
                    Image(systemName: visibility.iconName)
                        .foregroundColor(.secondary)
                }
                
                if memo.pinned == true {
                    Image(systemName: "flag.fill")
                        .renderingMode(.original)
                }
                
                Spacer()
                
                Menu {
                    normalMenu()
                } label: {
                    Image(systemName: "ellipsis")
                        .padding([.leading, .top, .bottom], 10)
                }
            }
            
            MemoCardContent(memo: memo, toggleTaskItem: toggleTaskItem(_:))
        }
        .padding([.top, .bottom], 5)
        .contextMenu {
            Button {
                UIPasteboard.general.setValue(memo.content, forPasteboardType: UTType.plainText.identifier)
            } label: {
                Label("memo.copy", systemImage: "doc.on.doc")
            }
        }
        .sheet(isPresented: $showingEdit) {
            MemoInput(memo: memo)
        }
    }
    
    @ViewBuilder
    private func normalMenu() -> some View {
        Button {
            Task {
                do {
                    try await memosViewModel.updateMemoOrganizer(id: memo.id, pinned: !(memo.pinned == true))
                } catch {
                    print(error)
                }
            }
        } label: {
            if memo.pinned == true {
                Label("memo.unpin", systemImage: "flag.slash")
            } else {
                Label("memo.pin", systemImage: "flag")
            }
        }
        Button {
            showingEdit = true
        } label: {
            Label("memo.edit", systemImage: "pencil")
        }
        ShareLink(item: memo.content) {
            Label("memo.share", systemImage: "square.and.arrow.up")
        }
        Button(role: .destructive, action: {
            Task {
                do {
                    try await memosViewModel.archiveMemo(id: memo.id)
                } catch {
                    print(error)
                }
            }
        }, label: {
            Label("memo.archive", systemImage: "archivebox")
        })
    }
    
    private func toggleTaskItem(_ configuration: TaskListMarkerConfiguration) async {
        do {
            guard var node = configuration.node else { return }
            node.checkbox = configuration.isCompleted ? .unchecked : .checked
            
            try await memosViewModel.editMemo(id: memo.id, content: node.root.format(), visibility: memo.visibility ?? .PRIVATE, resourceIdList: memo.resourceList?.map { $0.id })
        } catch {
            print(error)
        }
    }
}
