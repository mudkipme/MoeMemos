//
//  MemoComments.swift
//  MoeMemos
//
//  Created by Zhang Yunxin on 2026/9/1.
//

import SwiftUI
import Models

/// A single comment row.
@MainActor
struct MemoCommentCard: View {
    let comment: Memo
    let viewModel: MemoCommentsViewModel

    @State private var isEditingComment = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(comment.renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if let creatorName = comment.user?.nickname {
                    Text("@\(creatorName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.canDelete(comment) {
                    Menu {
                        Button {
                            isEditingComment = true
                        } label: {
                            Label("memo.edit", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }, label: {
                            Label("memo.delete", systemImage: "trash")
                        })
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding([.leading, .top, .bottom], 10)
                    }
                }
            }

            MemoCardContent(memo: comment, toggleTaskItem: nil, textSelectionEnabled: true)
        }
        .padding([.top, .bottom], 5)
        .confirmationDialog("memo.comment.delete.confirm", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("memo.action.ok", role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteComment(comment)
                    } catch {
                        print(error)
                    }
                }
            }
            Button("memo.action.cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isEditingComment) {
            MemoCommentEditSheet(comment: comment) { remoteId, content in
                try await viewModel.updateComment(remoteId: remoteId, content: content, original: comment)
            }
        }
    }
}

/// The list of comments of a memo, shared by the memo detail view and the explore comments sheet.
@MainActor
struct MemoCommentsList: View {
    let viewModel: MemoCommentsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.comments, id: \.self) { comment in
                MemoCommentCard(comment: comment, viewModel: viewModel)
            }
        }
    }
}

/// Sheet for editing a comment.
@MainActor
private struct MemoCommentEditSheet: View {
    let comment: Memo
    let onSave: (_ remoteId: String, _ content: String) async throws -> Void

    @State private var text: String
    @State private var saveError: Error?
    @State private var showingErrorAlert = false
    @Environment(\.dismiss) private var dismiss

    init(comment: Memo, onSave: @escaping (_ remoteId: String, _ content: String) async throws -> Void) {
        self.comment = comment
        self.onSave = onSave
        _text = State(initialValue: comment.content)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding(.horizontal)
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
                                    if let remoteId = comment.remoteId {
                                        try await onSave(remoteId, text)
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
}

/// Bottom input bar for composing a comment.
@MainActor
struct MemoCommentComposer: View {
    let sending: Bool
    let onSend: (_ content: String) async throws -> Void

    @State private var text = ""
    @State private var sendError: Error?
    @State private var showingErrorAlert = false
    @State private var isSubmitting = false

    private var isSending: Bool { sending || isSubmitting }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        composer
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .alert(NSLocalizedString("sync.failed.title", comment: "Error alert title"), isPresented: $showingErrorAlert) {
                Button("memo.action.ok", role: .cancel) {}
            } message: {
                Text(sendError?.localizedDescription ?? "")
            }
    }

    @ViewBuilder
    private var composer: some View {
        if #available(iOS 26.0, *) {
            composerContent
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        } else {
            composerContent
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
    }

    private var composerContent: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("memo.comment.placeholder", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.vertical, 11)
                .padding(.leading, 14)
                .frame(minHeight: 44)
                .disabled(isSending)

            Button(action: send) {
                ZStack {
                    Circle()
                        .fill(canSend || isSending ? Color.accentColor : Color(uiColor: .tertiarySystemFill))

                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(canSend ? Color.white : Color.secondary)
                    }
                }
                .frame(width: 36, height: 36)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("memo.comment.send"))
            .disabled(!canSend)
        }
        .padding(6)
    }

    private func send() {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await onSend(content)
                text = ""
            } catch {
                sendError = error
                showingErrorAlert = true
            }
        }
    }
}

/// Sheet showing the comments of an explore memo.
@MainActor
struct MemoCommentsSheet: View {
    let memoRemoteId: String

    @State private var viewModel: MemoCommentsViewModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.loading && viewModel.comments.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.comments.isEmpty {
                        ContentUnavailableView("memo.comment.empty", systemImage: "bubble.left")
                    } else {
                        ScrollView {
                            MemoCommentsList(viewModel: viewModel)
                                .padding()
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
            }
            .navigationTitle("memo.comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("input.close") { dismiss() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let viewModel {
                MemoCommentComposer(sending: viewModel.sending) { content in
                    try await viewModel.sendComment(content: content)
                }
            }
        }
        .task(id: memoRemoteId) {
            guard viewModel == nil else { return }
            let viewModel = MemoCommentsViewModel(memoRemoteId: memoRemoteId)
            self.viewModel = viewModel
            do {
                try await viewModel.loadComments()
            } catch {
                print(error)
            }
        }
    }
}
