//
//  ExploreMemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
import Models
import MemoKit

struct ExploreMemoCard: View {
    let memo: Memo
    let isAdmin: Bool
    let onEdit: (_ remoteId: String, _ content: String, _ visibility: MemoVisibility) async throws -> Void

    @State private var isEditingMemo = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(memo.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if let creatorName = memo.user?.nickname {
                    Text("@\(creatorName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if isAdmin {
                    Spacer()
                    Menu {
                        Button {
                            isEditingMemo = true
                        } label: {
                            Label("memo.edit", systemImage: "pencil")
                        }
                        ShareLink(item: memo.content) {
                            Label("memo.share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding([.leading, .top, .bottom], 10)
                    }
                }
            }
            .padding(.vertical, 5)

            MemoCardContent(memo: memo, toggleTaskItem: isAdmin ? { updatedContent in
                guard let remoteId = memo.remoteId else { return }
                Task {
                    try? await onEdit(remoteId, updatedContent, memo.visibility)
                }
            } : nil)
        }
        .padding([.top, .bottom], 5)
        .sheet(isPresented: $isEditingMemo) {
            ExploreEditMemoSheet(memo: memo, onSave: onEdit)
        }
    }
}

private struct ExploreEditMemoSheet: View {
    let memo: Memo
    let onSave: (_ remoteId: String, _ content: String, _ visibility: MemoVisibility) async throws -> Void

    @State private var text: String
    @State private var visibility: MemoVisibility
    @State private var saveError: Error?
    @State private var showingErrorAlert = false
    @Environment(\.dismiss) private var dismiss

    init(memo: Memo, onSave: @escaping (_ remoteId: String, _ content: String, _ visibility: MemoVisibility) async throws -> Void) {
        self.memo = memo
        self.onSave = onSave
        _text = State(initialValue: memo.content)
        _visibility = State(initialValue: memo.visibility)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                visibilityPicker
                    .padding(.horizontal)
                TextEditor(text: $text)
                    .padding(.horizontal)
            }
            .navigationTitle("input.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("input.close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            do {
                                if let remoteId = memo.remoteId {
                                    try await onSave(remoteId, text, visibility)
                                }
                                dismiss()
                            } catch {
                                saveError = error
                                showingErrorAlert = true
                            }
                        }
                    } label: {
                        Label("input.save", systemImage: "paperplane")
                    }
                    .disabled(text.isEmpty)
                }
            }
            .alert(NSLocalizedString("sync.failed.title", comment: "Error alert title"), isPresented: $showingErrorAlert) {
                Button("memo.action.ok", role: .cancel) {}
            } message: {
                Text(saveError?.localizedDescription ?? "")
            }
        }
    }

    private var visibilityPicker: some View {
        Menu {
            Section("input.visibility") {
                ForEach([MemoVisibility.public, .local, .private], id: \.self) { v in
                    Button {
                        visibility = v
                    } label: {
                        Label(v.title, systemImage: v.iconName)
                    }
                }
            }
        } label: {
            HStack {
                Label(visibility.title, systemImage: visibility.iconName)
                Image(systemName: "chevron.down")
            }
            .font(.footnote)
            .padding(4)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.green, lineWidth: 1)
            )
        }
    }
}
