//
//  SaveMemoIntent.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/13.
//

import Foundation
import AppIntents
import Account
import Models

struct SaveMemoIntent: AppIntent {
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
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let service = accountManager.accounts.first(where: { $0.key == account.id })?.remoteService() else { return .result(dialog: "Account not found.") }
        
        var resources: [Resource] = []
        if let attachments = attachments {
            for attachment in attachments {
                resources.append(try await service.createResource(filename: attachment.filename, data: attachment.data, type: attachment.type?.preferredMIMEType ?? "application/octet-stream", memoRemoteId: nil))
            }
        }
        _ = try await service.createMemo(content: content, visibility: nil, resources: resources, tags: nil)
        return .result(dialog: "Memo saved.")
    }
}
