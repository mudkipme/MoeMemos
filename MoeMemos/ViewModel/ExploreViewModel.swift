//
//  ExploreViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import Foundation
import Account
import Models
import Factory

@MainActor
@Observable class ExploreViewModel {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var service: RemoteService { get throws { try accountManager.mustCurrentRemoteService } }

    private(set) var memoList: [Memo] = []
    private(set) var loading = false
    private(set) var hasMore = false
    @ObservationIgnored private var nextPageToken: String? = nil
    
    @MainActor
    func loadMemos() async throws {
        do {
            loading = true
            let (response, nextPageToken) = try await service.listWorkspaceMemos(pageSize: 20, pageToken: nil)
            memoList = response
            loading = false
            hasMore = response.count >= 20
            self.nextPageToken = nextPageToken
        } catch {
            loading = false
            throw error
        }
    }
    
    @MainActor
    func loadMoreMemos() async throws {
        guard !loading && hasMore else { return }
        do {
            loading = true
            let (response, nextPageToken) = try await service.listWorkspaceMemos(pageSize: 20, pageToken: self.nextPageToken)
            memoList += response
            loading = false
            hasMore = response.count >= 20
            self.nextPageToken = nextPageToken
        } catch {
            loading = false
            throw error
        }
    }

    @MainActor
    func editMemo(remoteId: String, content: String, visibility: MemoVisibility) async throws {
        var updated = try await service.updateMemo(remoteId: remoteId, content: content, resources: nil, visibility: visibility, tags: nil, pinned: nil, updatedAt: nil)
        if let index = memoList.firstIndex(where: { $0.remoteId == remoteId }) {
            updated.user = memoList[index].user
            memoList[index] = updated
        }
    }
}
