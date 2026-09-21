//
//  MemoCommentsViewModel.swift
//  MoeMemos
//
//  Created by Zhang Yunxin on 2026/9/1.
//

import Foundation
import Account
import Models
import Factory

@MainActor
@Observable class MemoCommentsViewModel {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager

    let memoRemoteId: String
    private(set) var comments: [Memo] = []
    private(set) var loading = false
    private(set) var sending = false

    init(memoRemoteId: String) {
        self.memoRemoteId = memoRemoteId
    }

    private var commentService: MemoCommentService? {
        (try? accountManager.mustCurrentRemoteService) as? MemoCommentService
    }

    private var currentUserRemoteId: String? {
        if case .memosV1(_, let id, _) = accountManager.currentAccount {
            return id
        }
        return nil
    }

    /// Whether the current user may delete this comment (only own comments).
    func canDelete(_ comment: Memo) -> Bool {
        guard let currentUserRemoteId else { return false }
        return comment.user?.remoteId == currentUserRemoteId
    }

    @MainActor
    func loadComments() async throws {
        guard let service = commentService else { throw MoeMemosError.notLogin }
        do {
            loading = true
            comments = try await service.listMemoComments(memoRemoteId: memoRemoteId)
            loading = false
        } catch {
            loading = false
            throw error
        }
    }

    @MainActor
    func sendComment(content: String) async throws {
        guard let service = commentService else { throw MoeMemosError.notLogin }
        do {
            sending = true
            let comment = try await service.createMemoComment(memoRemoteId: memoRemoteId, content: content)
            comments.append(comment)
            sending = false
        } catch {
            sending = false
            throw error
        }
    }

    @MainActor
    func updateComment(remoteId: String, content: String, original: Memo) async throws {
        guard let service = commentService else { throw MoeMemosError.notLogin }
        do {
            sending = true
            var updated = try await service.updateMemo(
                remoteId: remoteId,
                content: content,
                resources: nil,
                visibility: nil,
                tags: nil,
                pinned: nil,
                updatedAt: nil
            )
            sending = false
            updated.user = original.user
            if let index = comments.firstIndex(where: { $0.remoteId == remoteId }) {
                comments[index] = updated
            }
        } catch {
            sending = false
            throw error
        }
    }

    @MainActor
    func deleteComment(_ comment: Memo) async throws {
        guard let service = commentService else { throw MoeMemosError.notLogin }
        guard let remoteId = comment.remoteId else { throw MoeMemosError.invalidParams }
        try await service.deleteMemo(remoteId: remoteId)
        comments.removeAll { $0.remoteId == comment.remoteId }
    }
}
