//
//  MemoryWidgetConfiguration.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/24.
//

import MemoSystem
import Foundation
import AppIntents
import Models
import MemoData

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MemoryWidgetConfiguration: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    static let intentClassName = "MemoryWidgetConfigurationIntent"

    static let title: LocalizedStringResource = "Memory Widget Configuration"
    static let description = IntentDescription("Configurate how the memory widget is updated")

    @Parameter(title: "Update")
    var frequency: MemoryUpdatePeriodAppEnum?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        // TODO: Place your refactored intent handler code here.
        return .result()
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct PinnedMemoryWidgetConfiguration: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Pinned Memory Widget Configuration"
    static let description = IntentDescription("Select one memo to keep showing in this widget")

    @Parameter(title: "Update")
    var frequency: MemoryUpdatePeriodAppEnum?

    @Parameter(title: "Memo")
    var memo: MemoryWidgetMemoEntity?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MemoryWidgetMemoEntity: AppEntity, Identifiable, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Memo"
    static let defaultQuery = MemoryWidgetMemoEntityQuery()

    let id: String
    let content: String
    let createdAt: Date

    var displayRepresentation: DisplayRepresentation {
        let title = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return DisplayRepresentation(title: "\(title.prefix(50))")
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MemoryWidgetMemoEntityQuery: EntityQuery {
    func entities(for identifiers: [MemoryWidgetMemoEntity.ID]) async throws -> [MemoryWidgetMemoEntity] {
        try await MainActor.run {
            let store = MemoEntityStore(context: AppInfo().modelContext)
            return try identifiers.compactMap { id in
                guard let entity = try store.entity(forLegacyIdentifier: id) else { return nil }
                return MemoryWidgetMemoEntity(id: id, content: entity.content, createdAt: entity.createdAt)
            }
        }
    }

    func suggestedEntities() async throws -> [MemoryWidgetMemoEntity] {
        try await loadSuggestedEntitiesFromStore()
    }

    func defaultResult() async -> MemoryWidgetMemoEntity? {
        return try? await suggestedEntities().first
    }
}

@MainActor
private func loadSuggestedEntitiesFromStore() async throws -> [MemoryWidgetMemoEntity] {
    let context = AppInfo().modelContext
    let accountKey = AccountManager(modelContext: context).currentAccount?.key
    return try MemoEntityStore(context: context).allEntities()
        .filter { $0.accountKey == accountKey }.prefix(100).compactMap { entity in
            guard let key = MemoEntityIdentifier(token: entity.id),
                  let token = PersistentIdentifierTokenCoder.encode(key.persistentID) else { return nil }
            return MemoryWidgetMemoEntity(id: token, content: entity.content, createdAt: entity.createdAt)
        }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
    static func frequencyParameterDisambiguationIntro(count: Int, frequency: MemoryUpdatePeriodAppEnum) -> Self {
        "There are \(count) options matching ‘\(frequency)’."
    }
    static func frequencyParameterConfirmation(frequency: MemoryUpdatePeriodAppEnum) -> Self {
        "Just to confirm, you wanted ‘\(frequency)’?"
    }
}
