//
//  AccountEntity.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/19.
//

import AppIntents
import Account
import Models

public struct AccountEntity: Identifiable, AppEntity {
    public let accountKey: String
    public let nickname: String

    public var id: String { accountKey }

    public static let defaultQuery = DefaultAccountEntityQuery()

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Account"

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(nickname)")
    }
}

public struct DefaultAccountEntityQuery: EntityQuery {
    @Dependency
    var accountViewModel: AccountViewModel
    
    public init() {}

    public func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        await MainActor.run(resultType: [AccountEntity].self) {
            accountViewModel.users.filter { user in
                identifiers.contains { id in
                    id == user.accountKey
                }
            }.map { AccountEntity(accountKey: $0.accountKey, nickname: $0.nickname) }
        }
    }

    public func suggestedEntities() async throws -> [AccountEntity] {
        await MainActor.run(resultType: [AccountEntity].self) {
            accountViewModel.users.map { .init(accountKey: $0.accountKey, nickname: $0.nickname) }
        }
    }

    public func defaultResult() async -> AccountEntity? {
        await MainActor.run(resultType: AccountEntity?.self) {
            accountViewModel.currentUser.map { .init(accountKey: $0.accountKey, nickname: $0.nickname) }
        }
    }
}
