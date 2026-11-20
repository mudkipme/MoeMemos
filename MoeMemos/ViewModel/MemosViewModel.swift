//
//  MemosViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import MemoData
import Foundation
import OSLog
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
enum BackgroundSyncThrottle {
    private static let minimumInterval: TimeInterval = 10
    private static var lastTriggerDates: [String: Date] = [:]

    static func canStartSync(for accountKey: String?, now: Date = Date()) -> Bool {
        let key = accountKey ?? ""
        if let lastTriggerDate = lastTriggerDates[key], now.timeIntervalSince(lastTriggerDate) < minimumInterval {
            return false
        }

        lastTriggerDates[key] = now
        return true
    }

    static func reset(for accountKey: String?) {
        let key = accountKey ?? ""
        lastTriggerDates.removeValue(forKey: key)
    }
}

@MainActor
@Observable class MemosViewModel {
    private static let logger = Logger(subsystem: "me.mudkip.MoeMemos", category: "Sync")
    private static let retryDelays: [Duration] = [.seconds(5), .seconds(15), .seconds(45)]

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
    private let networkMonitor = NetworkMonitor()
    @ObservationIgnored
    private var connectivityTask: Task<Void, Never>?
    @ObservationIgnored
    private var retryTask: Task<Void, Never>?
    @ObservationIgnored
    private var consecutiveTransientFailures = 0
    @ObservationIgnored
    private var boundSyncAccountKey: String?
    @ObservationIgnored
    private weak var boundSyncService: AnyObject?
    @ObservationIgnored
    var service: Service { get throws { try accountManager.mustCurrentService } }

    private var syncingAccountKeys: Set<String> = []

    private(set) var memoList: [StoredMemo] = [] {
        didSet {
            matrix = DailyUsageStat.calculateMatrix(memoList: memoList)
        }
    }
    private(set) var tags: [Tag] = []
    private(set) var nestedTags: [NestedTag] = []
    private(set) var matrix: [DailyUsageStat] = DailyUsageStat.initialMatrix
    private(set) var loadError: String?
    private(set) var inited = false
    private(set) var unsyncedCount = 0
    private(set) var syncAuthError = false

    var syncing: Bool {
        guard let accountKey = accountManager.currentAccount?.key else { return false }
        return syncingAccountKeys.contains(accountKey)
    }

    func startConnectivityMonitoring() {
        guard connectivityTask == nil else { return }
        connectivityTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var previouslyOnline: Bool?
            for await isOnline in self.networkMonitor.connectivityUpdates() {
                guard !Task.isCancelled else { break }
                let reconnected = (previouslyOnline == false && isOnline)
                previouslyOnline = isOnline
                if !isOnline {
                    self.retryTask?.cancel()
                    self.retryTask = nil
                    continue
                }
                if reconnected {
                    self.consecutiveTransientFailures = 0
                    self.retryTask?.cancel()
                    self.retryTask = nil
                    self.refreshSyncStatus()
                    guard let accountKey = self.accountManager.currentAccount?.key,
                          (try? self.service) is SyncableService,
                          self.unsyncedCount > 0 else {
                        continue
                    }
                    BackgroundSyncThrottle.reset(for: accountKey)
                    self.startBackgroundSync(bypassThrottle: true)
                }
            }
        }
    }

    func refreshSyncStatus() {
        guard let service = try? self.service, let syncService = service as? SyncableService else {
            unsyncedCount = 0
            syncAuthError = false
            return
        }
        bindSyncServiceIfNeeded(syncService, accountKey: accountManager.currentAccount?.key)
        unsyncedCount = syncService.pendingChangesCount()
        if let error = syncService.lastSyncError {
            syncAuthError = SyncErrorClassifier.classify(error) == .authenticationRequired
        } else {
            syncAuthError = false
        }
    }

    private func bindSyncServiceIfNeeded(_ syncService: SyncableService, accountKey: String?) {
        let object = syncService as AnyObject
        if boundSyncService === object && boundSyncAccountKey == accountKey {
            return
        }
        boundSyncService = object
        boundSyncAccountKey = accountKey
        retryTask?.cancel()
        retryTask = nil
        consecutiveTransientFailures = 0
        syncService.setStateChangeHandler { [weak self] in
            guard let self, self.accountManager.currentAccount?.key == accountKey else { return }
            self.unsyncedCount = syncService.pendingChangesCount()
            if let error = syncService.lastSyncError {
                self.syncAuthError = SyncErrorClassifier.classify(error) == .authenticationRequired
                if SyncErrorClassifier.shouldRetryAutomatically(error), self.unsyncedCount > 0 {
                    self.scheduleAutomaticRetry(for: accountKey)
                }
            } else {
                self.syncAuthError = false
            }
        }
    }
    
    @MainActor
    func loadMemos() async throws {
        let accountKey = accountManager.currentAccount?.key
        loadError = nil
        do {
            let service = try self.service
            if let syncService = service as? SyncableService {
                bindSyncServiceIfNeeded(syncService, accountKey: accountKey)
            } else {
                boundSyncService = nil
                boundSyncAccountKey = accountKey
            }
            let loadedMemos = try await service.listMemos()
            guard accountManager.currentAccount?.key == accountKey else { return }
            memoList = loadedMemos
            inited = true
            refreshSyncStatus()
            if service is SyncableService {
                startBackgroundSync()
            }
        } catch {
            guard accountManager.currentAccount?.key == accountKey else { return }
            loadError = error.localizedDescription
            throw error
        }
    }
    
    @MainActor
    func loadTags() async throws {
        let accountKey = accountManager.currentAccount?.key
        let service = try self.service
        let loadedTags = try await service.listTags()
        guard accountManager.currentAccount?.key == accountKey else { return }
        tags = loadedTags
        nestedTags = NestedTag.fromTagList(loadedTags.map { $0.name })
    }
    
    @MainActor
    func createMemo(content: String, visibility: MemoVisibility = .private, resources: [PersistentIdentifier]? = nil, tags: [String]?, location: MemoLocation? = nil) async throws {
        let service = try self.service
        let created = try await service.createMemo(content: content, visibility: visibility, resources: resources ?? [], tags: tags, location: location)
        let insertIndex = memoList.firstIndex(where: { !$0.pinned }) ?? memoList.endIndex
        memoList.insert(created, at: insertIndex)
        refreshSyncStatus()
        try await loadTags()
    }
    
    @MainActor
    func updateMemoOrganizer(id: PersistentIdentifier, pinned: Bool) async throws {
        let service = try self.service
        _ = try await service.updateMemo(id: id, content: nil, resources: nil, visibility: nil, tags: nil, pinned: pinned)
        refreshSyncStatus()
    }
    
    @MainActor
    func archiveMemo(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.archiveMemo(id: id)
        memoList = memoList.filter({ memo in
            memo.id != id
        })
        refreshSyncStatus()
    }
    
    @MainActor
    func editMemo(id: PersistentIdentifier, content: String, visibility: MemoVisibility = .private, resources: [PersistentIdentifier]? = nil, tags: [String]?, location: MemoLocationUpdate? = nil) async throws {
        let service = try self.service
        _ = try await service.updateMemo(id: id, content: content, resources: resources, visibility: visibility, tags: tags, pinned: nil, location: service.supportsMemoLocations ? location : nil)
        refreshSyncStatus()
        try await loadTags()
    }

    @MainActor
    func deleteMemo(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.deleteMemo(id: id)
        memoList = memoList.filter({ memo in
            memo.id != id
        })
        refreshSyncStatus()
        try await loadTags()
    }

    @MainActor
    func syncNow(trigger: SyncTrigger = .manual, forceHigherV1VersionSync: Bool = false) async throws {
        guard let account = accountManager.currentAccount else { return }
        let accountKey = account.key
        guard !syncingAccountKeys.contains(accountKey) else { return }
        let service = try self.service
        guard let syncService = service as? SyncableService else { return }
        bindSyncServiceIfNeeded(syncService, accountKey: accountKey)

        if trigger == .manual {
            retryTask?.cancel()
            retryTask = nil
            consecutiveTransientFailures = 0
        }

        let approvalToPersist: HigherV1SyncApprovalToPersist?
        do {
            switch try await evaluateSyncGate(account: account, trigger: trigger, forceHigherV1VersionSync: forceHigherV1VersionSync) {
            case .allow(let approval):
                approvalToPersist = approval
            case .silentlyBlock:
                return
            case .manualError(let error):
                throw error
            }
        } catch {
            if accountManager.currentAccount?.key == accountKey,
               SyncErrorClassifier.classify(error) == .authenticationRequired {
                syncAuthError = true
            }
            throw error
        }

        guard accountManager.currentAccount?.key == accountKey else { return }

        syncingAccountKeys.insert(accountKey)
        defer {
            syncingAccountKeys.remove(accountKey)
            if accountManager.currentAccount?.key == accountKey {
                refreshSyncStatus()
            }
        }

        do {
            try await syncService.sync()
        } catch {
            if accountManager.currentAccount?.key == accountKey {
                syncAuthError = SyncErrorClassifier.classify(error) == .authenticationRequired
                if let refreshedMemos = try? await service.listMemos(),
                   accountManager.currentAccount?.key == accountKey {
                    memoList = refreshedMemos
                    try? await loadTags()
                }
            }
            throw error
        }

        consecutiveTransientFailures = 0
        retryTask?.cancel()
        retryTask = nil

        if let approvalToPersist {
            rememberApprovedHigherV1SyncVersion(version: approvalToPersist.version, accountKey: approvalToPersist.accountKey)
        }

        guard accountManager.currentAccount?.key == accountKey else { return }
        let syncedMemos = try await service.listMemos()
        guard accountManager.currentAccount?.key == accountKey else { return }
        memoList = syncedMemos
        try await loadTags()
    }

    @MainActor
    private func startBackgroundSync(bypassThrottle: Bool = false) {
        let accountKey = accountManager.currentAccount?.key
        guard bypassThrottle || BackgroundSyncThrottle.canStartSync(for: accountKey) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.syncNow(trigger: .automatic)
            } catch {
                Self.logger.error("Automatic sync failed: \(error.localizedDescription, privacy: .public)")
                guard self.accountManager.currentAccount?.key == accountKey else { return }
                if SyncErrorClassifier.shouldRetryAutomatically(error), self.unsyncedCount > 0 {
                    self.scheduleAutomaticRetry(for: accountKey)
                }
            }
        }
    }

    @MainActor
    private func scheduleAutomaticRetry(for accountKey: String?) {
        guard let accountKey,
              accountManager.currentAccount?.key == accountKey,
              retryTask == nil,
              consecutiveTransientFailures < Self.retryDelays.count else {
            return
        }
        let delay = Self.retryDelays[consecutiveTransientFailures]
        consecutiveTransientFailures += 1
        retryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self else { return }
            self.retryTask = nil
            guard self.accountManager.currentAccount?.key == accountKey, self.unsyncedCount > 0 else { return }
            self.startBackgroundSync(bypassThrottle: true)
        }
    }

    private func evaluateSyncGate(account: Account, trigger: SyncTrigger, forceHigherV1VersionSync: Bool) async throws -> SyncGateDecision {
        switch account {
        case .local:
            return .allow(approvalToPersist: nil)
        case .memosV0, .memosV1:
            let serverVersion: MemosVersion
            do {
                serverVersion = try await detectMemosVersion(account: account)
            } catch {
                if trigger == .automatic {
                    let kind = SyncErrorClassifier.classify(error)
                    if kind == .transient || kind == .authenticationRequired {
                        throw error
                    }
                    Self.logger.error("Version check failed during automatic sync: \(error.localizedDescription, privacy: .public)")
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
