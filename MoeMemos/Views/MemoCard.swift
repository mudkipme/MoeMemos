//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI
import Models
import Env

@MainActor
struct MemoCard: View {
    let memo: Memo
    let defaultMemoVisilibity: MemoVisibility?
    
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AppPath.self) private var appPath
    @State private var showingDeleteConfirmation = false
    
    init(_ memo: Memo, defaultMemoVisibility: MemoVisibility) {
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
        .confirmationDialog("memo.delete.confirm", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("memo.action.ok", role: .destructive) {
                Task {
                    guard let remoteId = memo.remoteId else { return }
                    try await memosViewModel.deleteMemo(remoteId: remoteId)
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
                    guard let remoteId = memo.remoteId else { return }
                    try await memosViewModel.updateMemoOrganizer(remoteId: remoteId, pinned: !(memo.pinned == true))
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
            appPath.presentedSheet = .editMemo(memo)
        } label: {
            Label("memo.edit", systemImage: "pencil")
        }
        ShareLink(item: memo.content) {
            Label("memo.share", systemImage: "square.and.arrow.up")
        }
        Button(role: .destructive, action: {
            Task {
                do {
                    guard let remoteId = memo.remoteId else { return }
                    try await memosViewModel.archiveMemo(remoteId: remoteId)
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
            guard let remoteId = memo.remoteId else { return }
            try await memosViewModel.editMemo(remoteId: remoteId, content: node.root.format(), visibility: memo.visibility, resources: memo.resources, tags: nil)
        } catch {
            print(error)
        }
    }
}
