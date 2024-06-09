//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI
import MemosV0Service
import Models

@MainActor
struct MemoCard: View {
    let memo: MemosMemo
    let defaultMemoVisilibity: MemoVisibility?
    
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    
    init(_ memo: MemosMemo, defaultMemoVisibility: MemoVisibility) {
        self.memo = memo
        self.defaultMemoVisilibity = defaultMemoVisibility
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(memo.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if let visibility = memo.visibility, let defaultMemoVisilibity = defaultMemoVisilibity, MemoVisibility(visibility) != defaultMemoVisilibity {
                    Image(systemName: MemoVisibility(visibility).iconName)
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
            
            try await memosViewModel.editMemo(id: memo.id, content: node.root.format(), visibility: memo.visibility ?? .PRIVATE, resourceIdList: memo.resourceList?.map { $0.id })
        } catch {
            print(error)
        }
    }
}
