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

enum SyncTrigger {
    case automatic
    case manual
}

enum ManualSyncCompatibilityError: LocalizedError {
    case unsupportedVersion
    case higherV1VersionNeedsConfirmation(version: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return moeMemosSupportedMemosVersionsMessage
        case .higherV1VersionNeedsConfirmation(version: _):
            return moeMemosHigherMemosVersionSyncWarning
        }
    }
}

@MainActor
@Observable class MemosViewModel {
    private struct HigherV1SyncApprovalToPersist {
        let version: String
        let accountKey: String
    }

    private enum SyncGateDecision {
        case allow(approvalToPersist: HigherV1SyncApprovalToPersist?)
        case silentlyBlock
        case manualError(ManualSyncCompatibilityError)
    }

    private static let higherV1SyncApprovalStorageKeyPrefix = "moememos.v1.sync.approved.versions"

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
    func syncNow(trigger: SyncTrigger = .manual, forceHigherV1VersionSync: Bool = false) async throws {
        guard !syncing else { return }
        let service = try self.service
        guard let syncService = service as? SyncableService else { return }

        let approvalToPersist: HigherV1SyncApprovalToPersist?
        switch try await evaluateSyncGate(trigger: trigger, forceHigherV1VersionSync: forceHigherV1VersionSync) {
        case .allow(let approval):
            approvalToPersist = approval
        case .silentlyBlock:
            return
        case .manualError(let error):
            throw error
        }

        syncing = true
        defer {
            syncing = false
        }

        try await syncService.sync()
        memoList = try await service.listMemos()
        try await loadTags()
        if let approvalToPersist {
            rememberApprovedHigherV1SyncVersion(version: approvalToPersist.version, accountKey: approvalToPersist.accountKey)
        }
    }

    @MainActor
    private func startBackgroundSync() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.syncNow(trigger: .automatic)
            } catch {
                return
            }
        }
    }

    private func evaluateSyncGate(trigger: SyncTrigger, forceHigherV1VersionSync: Bool) async throws -> SyncGateDecision {
        guard let account = accountManager.currentAccount else {
            return .allow(approvalToPersist: nil)
        }

        switch account {
        case .local:
            return .allow(approvalToPersist: nil)
        case .memosV0, .memosV1:
            let serverVersion: MemosVersion
            do {
                serverVersion = try await detectMemosVersion(account: account)
            } catch {
                if trigger == .automatic {
                    return .silentlyBlock
                }
                throw error
            }

            switch evaluateMemosVersionCompatibility(serverVersion) {
            case .supported:
                return .allow(approvalToPersist: nil)
            case .unsupported:
                return trigger == .automatic ? .silentlyBlock : .manualError(.unsupportedVersion)
            case .v1HigherThanSupported(version: let version):
                if hasApprovedHigherV1SyncVersion(version: version, accountKey: account.key) {
                    return .allow(approvalToPersist: nil)
                }
                if trigger == .automatic {
                    return .silentlyBlock
                }
                if forceHigherV1VersionSync {
                    return .allow(approvalToPersist: .init(version: version, accountKey: account.key))
                }
                return .manualError(.higherV1VersionNeedsConfirmation(version: version))
            }
        }
    }

    private func higherV1SyncApprovalStorageKey(accountKey: String) -> String {
        "\(Self.higherV1SyncApprovalStorageKeyPrefix).\(accountKey)"
    }

    private func hasApprovedHigherV1SyncVersion(version: String, accountKey: String) -> Bool {
        let key = higherV1SyncApprovalStorageKey(accountKey: accountKey)
        let versions = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        return versions.contains(version)
    }

    private func rememberApprovedHigherV1SyncVersion(version: String, accountKey: String) {
        let key = higherV1SyncApprovalStorageKey(accountKey: accountKey)
        var versions = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        versions.insert(version)
        UserDefaults.standard.set(Array(versions), forKey: key)
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
