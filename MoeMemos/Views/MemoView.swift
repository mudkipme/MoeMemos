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

@MainActor
struct MemoView: View {
    let memo: StoredMemo
    let defaultMemoVisibility: MemoVisibility?

    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AppPath.self) private var appPath
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    Text(memo.renderTime())
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    if memo.visibility != defaultMemoVisibility {
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

                MemoCardContent(memo: memo, toggleTaskItem: toggleTaskItem)
            }
            .padding()
        }
        .navigationTitle(memo.renderTime())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    normalMenu()
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
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
                    dismiss()
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

    private func toggleTaskItem(_ listItem: ListItem) async {
        do {
            var node = listItem
            node.checkbox = listItem.checkbox == .checked ? .unchecked : .checked
            let resourceIds = memo.resources.filter { !$0.softDeleted }.map(\.id)
            try await memosViewModel.editMemo(id: memo.id, content: node.root.format(), visibility: memo.visibility, resources: resourceIds, tags: nil)
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
