//
//  ArchivedMemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ArchivedMemoCard: View {
    let memo: Memo
    let archivedViewModel: ArchivedMemoListViewModel

    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var showingDeleteConfirmation = false

    init(_ memo: Memo, archivedViewModel: ArchivedMemoListViewModel) {
        self.memo = memo
        self.archivedViewModel = archivedViewModel
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(memo.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                                
                Spacer()
                
                Menu {
                    archivedMenu()
                } label: {
                    Image(systemName: "ellipsis")
                        .padding([.leading, .top, .bottom], 10)
                }
            }
            
            MemoCardContent(memo: memo, toggleTaskItem: nil)
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
                    try await archivedViewModel.deleteMemo(id: memo.id)
                }
            }
            Button("memo.action.cancel", role: .cancel) {}
        }
    }
    
    @ViewBuilder
    private func archivedMenu() -> some View {
        Button {
            Task {
                do {
                    try await archivedViewModel.restoreMemo(id: memo.id)
                    try await memosViewModel.loadMemos()
                } catch {
                    print(error)
                }
            }
        } label: {
            Label("memo.restore", systemImage: "tray.and.arrow.up")
        }
        Button(role: .destructive, action: {
            showingDeleteConfirmation = true
        }, label: {
            Label("memo.delete", systemImage: "trash")
        })
    }
}

struct ArchivedMemoCard_Previews: PreviewProvider {
    static var previews: some View {
        ArchivedMemoCard(Memo(id: 1, createdTs: .now.addingTimeInterval(-100), creatorId: 1, creatorName: nil, content: "Hello world\n\nThis is a **multiline** statement and thank you for everything.", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: .private, resourceList: nil), archivedViewModel: ArchivedMemoListViewModel())
            .environmentObject(MemosViewModel())
    }
}
