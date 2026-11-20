//
//  SaveMemoIntent.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/13.
//

import MemoSystem
import MemoData
import Foundation
import AppIntents
import Models
import SwiftData

struct SaveMemoIntent: AppIntent {
    private static let maxUploadSizeBytes: Int64 = 1_073_741_824
    static let title: LocalizedStringResource = "Save Memo"
    static let description = "Save a memo"
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Account")
    var account: AccountEntity
    
    @Parameter(
        title: "Content",
        inputOptions: .init(multiline: true),
        requestValueDialog: IntentDialog("Any thoughts…"))
    var content: String
    
    @Parameter(title: "Attachments")
    var attachments: [IntentFile]?
    
    @Dependency
    var accountManager: AccountManager
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<MemoEntity> {
        MemoSpotlightIndex.shared.startObserving()
        guard let service = accountManager.service(for: account.id) else { throw MemoIntentError.notFound }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(attachments ?? []).isEmpty else {
            throw MemoIntentError.emptyContent
        }
        for attachment in attachments ?? [] {
            try validateUploadSize(Int64(attachment.data.count))
        }
        
        var resourceIds: [PersistentIdentifier] = []
        if let attachments = attachments {
            for attachment in attachments {
                let data = attachment.data
                try validateUploadSize(Int64(data.count))
                let created = try await service.createResource(
                    filename: attachment.filename,
                    data: data,
                    type: attachment.type?.preferredMIMEType ?? "application/octet-stream",
                    memoId: nil
                )
                resourceIds.append(created.id)
            }
        }
        let tags = MemoTagExtractor.extract(from: content)
        let memo = try await service.createMemo(content: content, visibility: nil, resources: resourceIds, tags: tags)
        await MemoSpotlightIndex.shared.flush()
        if let pendingService = service as? PendingOperationsService {
            await pendingService.waitForPendingOperations(timeout: .seconds(10))
        }
        guard let entity = MemoEntity(memo: memo, accountName: account.nickname) else {
            throw MemoIntentError.notFound
        }
        return .result(value: entity, dialog: "Memo saved.")
    }

    private func validateUploadSize(_ size: Int64) throws {
        if size > Self.maxUploadSizeBytes {
            throw MoeMemosError.fileTooLarge(Self.maxUploadSizeBytes)
        }
    }
}
