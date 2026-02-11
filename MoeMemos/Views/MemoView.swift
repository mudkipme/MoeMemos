//
//  MemoView.swift
//  MoeMemos
//
//  Created by Mudkip on 2026/2/8.
//

import SwiftUI
import UniformTypeIdentifiers
import Models
import Env
import Markdown
import SwiftData
import Account

@MainActor
struct MemoView: View {
    let memoId: PersistentIdentifier

    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AccountViewModel.self) private var accountViewModel: AccountViewModel
    @Environment(AppPath.self) private var appPath
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if let memo {
                ScrollView {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(memo.renderTime())
                                .font(.footnote)
                                .foregroundColor(.secondary)

                            if memo.visibility != accountViewModel.currentUser?.defaultVisibility {
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
                        }

                        MemoCardContent(memo: memo) { listItem in
                            await toggleTaskItem(listItem, for: memo)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("Memo not found", systemImage: "note.text")
                    .task(id: memoId) {
                        try? await memosViewModel.loadMemos()
                    }
            }
        }
        .navigationTitle(memo?.renderTime() ?? "Memo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let memo {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        normalMenu(memo)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .confirmationDialog("memo.delete.confirm", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("memo.action.ok", role: .destructive) {
                Task {
                    guard let memo else {
                        return
                    }
                    try await memosViewModel.deleteMemo(id: memo.id)
                    dismiss()
                }
            }
            Button("memo.action.cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func normalMenu(_ memo: StoredMemo) -> some View {
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
        Button {
            UIPasteboard.general.setValue(memo.content, forPasteboardType: UTType.plainText.identifier)
        } label: {
            Label("memo.copy", systemImage: "doc.on.doc")
        }
        ShareLink(item: memo.content) {
            Label("memo.share", systemImage: "square.and.arrow.up")
        }
        Button(role: .destructive, action: {
            Task {
                do {
                    try await memosViewModel.archiveMemo(id: memo.id)
                    dismiss()
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

    private func toggleTaskItem(_ listItem: ListItem, for memo: StoredMemo) async {
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

    private var memo: StoredMemo? {
        if let memo = memosViewModel.memoList.first(where: { $0.id == memoId }) {
            return memo
        }
        return (try? memosViewModel.service)?.memo(id: memoId)
    }
}
