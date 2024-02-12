//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

struct MemoCard: View {
    let memo: Memo
    let defaultMemoVisilibity: MemosVisibility?
    
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var showingEdit = false
    @State private var showingLegacyShareSheet = false
    @State private var showingDeleteConfirmation = false
    
    init(_ memo: Memo, defaultMemoVisibility: MemosVisibility) {
        self.memo = memo
        self.defaultMemoVisilibity = defaultMemoVisibility
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(memo.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if defaultMemoVisilibity != nil && memo.visibility != defaultMemoVisilibity {
                    Image(systemName: memo.visibility.iconName)
                        .foregroundColor(.secondary)
                }
                
                if memo.pinned {
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
        .confirmationDialog("memo.delete.confirm", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("memo.action.ok", role: .destructive) {
                Task {
                    try await memosViewModel.deleteMemo(id: memo.id)
                }
            }
            Button("memo.action.cancel", role: .cancel) {}
        }
    }
    
    @ViewBuilder
    private func normalMenu() -> some View {
        Button {
            Task {
                do {
                    try await memosViewModel.updateMemoOrganizer(id: memo.id, pinned: !memo.pinned)
                } catch {
                    print(error)
                }
            }
        } label: {
            if memo.pinned {
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
        if #available(iOS 16, *) {
            ShareLink(item: memo.content) {
                Label("memo.share", systemImage: "square.and.arrow.up")
            }
        } else {
            Button {
                showingLegacyShareSheet = true
            } label: {
                Label("memo.share", systemImage: "square.and.arrow.up")
            }
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
        Button(role: .destructive, action: {
            showingDeleteConfirmation = true
        }, label: {
            Label("memo.delete", systemImage: "trash")
        })
    }
    
    private func toggleTaskItem(_ configuration: TaskListMarkerConfiguration) async {
        do {
            guard var node = configuration.node else { return }
            node.checkbox = configuration.isCompleted ? .unchecked : .checked
            
            try await memosViewModel.editMemo(id: memo.id, content: node.root.format(), visibility: memo.visibility, resourceIdList: memo.resourceList?.map { $0.id })
        } catch {
            print(error)
        }
    }
}

struct MemoCard_Previews: PreviewProvider {
    static var previews: some View {
        MemoCard(Memo(id: 1, createdTs: .now.addingTimeInterval(-100), creatorId: 1, creatorName: nil, content: "Hello world\n\nThis is a **multiline** statement and thank you for everything.", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: .private, resourceList: nil), defaultMemoVisibility: .private)
            .environmentObject(MemosViewModel())
    }
}
