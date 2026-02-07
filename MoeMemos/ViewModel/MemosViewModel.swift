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
import SwiftData

@MainActor
@Observable class MemosViewModel {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var service: Service { get throws { try accountManager.mustCurrentService } }

    private(set) var memoList: [StoredMemo] = [] {
        didSet {
            matrix = DailyUsageStat.calculateMatrix(memoList: memoList)
        }
    }
    private(set) var tags: [Tag] = []
    private(set) var nestedTags: [NestedTag] = []
    private(set) var matrix: [DailyUsageStat] = DailyUsageStat.initialMatrix
    private(set) var inited = false
    private(set) var syncing = false
    
    @MainActor
    func loadMemos() async throws {
        let service = try self.service
        memoList = try await service.listMemos()
        inited = true
        if service is SyncableService {
            startBackgroundSync()
        }
    }
    
    @MainActor
    func loadTags() async throws {
        let service = try self.service
        tags = try await service.listTags()
        nestedTags = NestedTag.fromTagList(tags.map { $0.name })
    }
    
    @MainActor
    func createMemo(content: String, visibility: MemoVisibility = .private, resources: [PersistentIdentifier]? = nil, tags: [String]?) async throws {
        let service = try self.service
        let created = try await service.createMemo(content: content, visibility: visibility, resources: resources ?? [], tags: tags)
        memoList.insert(created, at: 0)
        try await loadTags()
    }
    
    @MainActor
    func updateMemoOrganizer(id: PersistentIdentifier, pinned: Bool) async throws {
        let service = try self.service
        _ = try await service.updateMemo(id: id, content: nil, resources: nil, visibility: nil, tags: nil, pinned: pinned)
    }
    
    @MainActor
    func archiveMemo(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.archiveMemo(id: id)
        memoList = memoList.filter({ memo in
            memo.id != id
        })
    }
    
    @MainActor
    func editMemo(id: PersistentIdentifier, content: String, visibility: MemoVisibility = .private, resources: [PersistentIdentifier]? = nil, tags: [String]?) async throws {
        let service = try self.service
        _ = try await service.updateMemo(id: id, content: content, resources: resources, visibility: visibility, tags: tags, pinned: nil)
        try await loadTags()
    }

    @MainActor
    func deleteMemo(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.deleteMemo(id: id)
        memoList = memoList.filter({ memo in
            memo.id != id
        })
        try await loadTags()
    }

    @MainActor
    func syncNow() async throws {
        guard !syncing else { return }
        let service = try self.service
        guard let syncService = service as? SyncableService else { return }

        syncing = true
        defer {
            syncing = false
        }

        try await syncService.sync()
        memoList = try await service.listMemos()
        try await loadTags()
    }

    @MainActor
    private func startBackgroundSync() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.syncNow()
            } catch {
                return
            }
        }
    }
}

extension Container {
    @MainActor
    var memosViewModel: Factory<MemosViewModel> {
        self { @MainActor in
            MemosViewModel()
        }.shared
    }
}
