//
//  MemosViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation
import Account
import Models
import Factory

@Observable class MemosViewModel {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var service: RemoteService { get throws { try accountManager.mustCurrentService } }

    private(set) var memoList: [Memo] = [] {
        didSet {
            matrix = DailyUsageStat.calculateMatrix(memoList: memoList)
        }
    }
    private(set) var tags: [Tag] = []
    private(set) var nestedTags: [NestedTag] = []
    private(set) var matrix: [DailyUsageStat] = DailyUsageStat.initialMatrix
    private(set) var inited = false
    private(set) var loading = false
    
    @MainActor
    func loadMemos() async throws {
        do {
            loading = true
            let response = try await service.listMemos()
            memoList = response
            loading = false
            inited = true
        } catch {
            loading = false
            throw error
        }
    }
    
    @MainActor
    func loadTags() async throws {
        tags = try await service.listTags()
        nestedTags = NestedTag.fromTagList(tags.map { $0.name })
    }
    
    @MainActor
    func createMemo(content: String, visibility: MemoVisibility = .private, resources: [Resource]? = nil, tags: [String]?) async throws {
        let response = try await service.createMemo(content: content, visibility: visibility, resources: resources ?? [], tags: tags)
        memoList.insert(response, at: 0)
        try await loadTags()
    }
    
    @MainActor
    private func updateMemo(_ memo: Memo) {
        for (i, item) in memoList.enumerated() {
            if memo.remoteId != nil && item.remoteId == memo.remoteId {
                memoList[i] = memo
                break
            }
        }
    }
    
    @MainActor
    func updateMemoOrganizer(remoteId: String, pinned: Bool) async throws {
        let response = try await service.updateMemo(remoteId: remoteId, content: nil, resources: nil, visibility: nil, tags: nil, pinned: pinned)
        updateMemo(response)
    }
    
    @MainActor
    func archiveMemo(remoteId: String) async throws {
        try await service.archiveMemo(remoteId: remoteId)
        memoList = memoList.filter({ memo in
            memo.remoteId != remoteId
        })
    }
    
    @MainActor
    func editMemo(remoteId: String, content: String, visibility: MemoVisibility = .private, resources: [Resource]? = nil, tags: [String]?) async throws {
        let response = try await service.updateMemo(remoteId: remoteId, content: content, resources: resources, visibility: visibility, tags: nil, pinned: nil)
        updateMemo(response)
        try await loadTags()
    }

    @MainActor
    func deleteMemo(remoteId: String) async throws {
        _ = try await service.deleteMemo(remoteId: remoteId)
        memoList = memoList.filter({ memo in
            memo.remoteId != remoteId
        })
    }
}

extension Container {
    var memosViewModel: Factory<MemosViewModel> {
        self { MemosViewModel() }.shared
    }
}
