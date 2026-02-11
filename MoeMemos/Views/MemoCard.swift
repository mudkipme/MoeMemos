//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import UniformTypeIdentifiers
import Models
import Env
import SwiftData
import Markdown

@MainActor
struct MemoCard: View {
    let memo: StoredMemo
    let defaultMemoVisilibity: MemoVisibility?
    
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AppPath.self) private var appPath
    @State private var showingDeleteConfirmation = false
    
    init(_ memo: StoredMemo, defaultMemoVisibility: MemoVisibility) {
        self.memo = memo
        self.defaultMemoVisilibity = defaultMemoVisibility
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(memo.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if memo.visibility != defaultMemoVisilibity {
                    Image(systemName: memo.visibility.iconName)
                        .foregroundColor(.secondary)
                }
                
                if memo.pinned == true {
                    Image(systemName: "flag.fill")
                        .renderingMode(.original)
                }

                if memo.syncState != .synced {
                    Image(systemName: syncIconName(for: memo.syncState))
                        .imageScale(.small)
                        .foregroundStyle(.orange)
                }

                Spacer()

                Menu {
                    normalMenu()
                } label: {
                    Image(systemName: "ellipsis")
                        .padding([.leading, .top, .bottom], 10)
                }
            }
            
            MemoCardContent(memo: memo, toggleTaskItem: toggleTaskItem, truncate: true)
        }
        .padding([.top, .bottom], 5)
        .contextMenu {
            Button {
                UIPasteboard.general.setValue(memo.content, forPasteboardType: UTType.plainText.identifier)
            } label: {
                Label("memo.copy", systemImage: "doc.on.doc")
            }
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
            appPath.presentedSheet = .editMemo(memo.id)
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
    
    private func toggleTaskItem(_ listItem: ListItem) async {
        do {
            var node = listItem
            node.checkbox = listItem.checkbox == .checked ? .unchecked : .checked
            let resourceIds = memo.resources.filter { !$0.softDeleted }.map(\.id)
            let updatedContent = MemoTagMarkdownPreprocessor.restoreRawMarkdown(node.root.format())
            try await memosViewModel.editMemo(id: memo.id, content: updatedContent, visibility: memo.visibility, resources: resourceIds, tags: nil)
        } catch {
            print(error)
        }
    }

    private func syncIconName(for state: SyncState) -> String {
        switch state {
        case .synced:
            return "checkmark.icloud"
        case .pendingCreate:
            return "plus.circle"
        case .pendingUpdate:
            return "arrow.triangle.2.circlepath"
        case .pendingDelete:
            return "trash"
        }
    }
}
