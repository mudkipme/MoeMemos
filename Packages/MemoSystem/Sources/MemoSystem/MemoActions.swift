import MemoData
import AppIntents
import Foundation
import Models
import SwiftData

public enum MemoIntentError: LocalizedError {
    case notFound
    case emptyContent

    public var errorDescription: String? {
        switch self {
        case .notFound: String(localized: "This memo or its account is no longer available.")
        case .emptyContent: String(localized: "Enter some text or attach a file.")
        }
    }
}

public struct OpenMemoIntent: OpenIntent {
    public static let persistentIdentifier = "OpenMemoIntent"
    public static let title: LocalizedStringResource = "Open Memo"
    public static let openAppWhenRun = true
    @Parameter(title: "Memo") public var target: MemoEntity
    @Dependency private var navigator: MemoNavigator
    public static var parameterSummary: some ParameterSummary { Summary("Open \(\.$target)") }

    public init() {}

    init(target: MemoEntity, navigator: MemoNavigator) {
        self.target = target
        self.navigator = navigator
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        try navigator.openMemo(identifier: target.id)
        return .result()
    }
}

public struct FindMemosIntent: AppIntent {
    public static let persistentIdentifier = "FindMemosIntent"
    public static let title: LocalizedStringResource = "Find Memos"
    public static let description = IntentDescription("Find saved memos by text or tag, across your accounts.")
    @Parameter(title: "Search") public var search: String
    public static var parameterSummary: some ParameterSummary { Summary("Find memos matching \(\.$search)") }
    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<[MemoEntity]> {
        .result(value: try await MemoEntityQuery().entities(matching: search))
    }
}

public struct AppendToMemoIntent: AppIntent {
    public static let persistentIdentifier = "AppendToMemoIntent"
    public static let title: LocalizedStringResource = "Append to Memo"
    @Parameter(title: "Memo") public var memo: MemoEntity
    @Parameter(title: "Text", inputOptions: .init(multiline: true)) public var text: String
    public static var parameterSummary: some ParameterSummary { Summary("Append \(\.$text) to \(\.$memo)") }
    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<MemoEntity> {
        .result(value: try await MemoActions.append(text, to: memo.id))
    }
}

public struct PinMemoIntent: AppIntent {
    public static let persistentIdentifier = "PinMemoIntent"
    public static let title: LocalizedStringResource = "Pin Memo"
    @Parameter(title: "Memo") public var memo: MemoEntity
    @Parameter(title: "Pinned", default: true) public var pinned: Bool
    public static var parameterSummary: some ParameterSummary { Summary("Set \(\.$memo) pinned to \(\.$pinned)") }
    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<MemoEntity> {
        .result(value: try await MemoActions.pin(memo.id, pinned: pinned))
    }
}

@MainActor
public enum MemoActions {
    public static func append(_ text: String, to identifier: String) async throws -> MemoEntity {
        MemoSpotlightIndex.shared.startObserving()
        let context = AppInfo().modelContext
        return try await append(text, to: identifier, store: MemoEntityStore(context: context),
                                serviceForAccount: AccountManager(modelContext: context).service(for:))
    }

    static func append(_ text: String, to identifier: String, store: MemoEntityStore,
                       serviceForAccount: (String) -> (any Service)?) async throws -> MemoEntity {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MemoIntentError.emptyContent }
        guard let memo = try store.memo(for: identifier),
              let service = serviceForAccount(memo.accountKey) else { throw MemoIntentError.notFound }
        let content = memo.content.isEmpty ? text : memo.content + "\n" + text
        _ = try await service.updateMemo(id: memo.id, content: content, resources: nil, visibility: nil, tags: nil, pinned: nil)
        await MemoSpotlightIndex.shared.flush()
        guard let entity = try store.entities(for: [identifier]).first else { throw MemoIntentError.notFound }
        return entity
    }

    public static func pin(_ identifier: String, pinned: Bool) async throws -> MemoEntity {
        MemoSpotlightIndex.shared.startObserving()
        let context = AppInfo().modelContext
        return try await pin(identifier, pinned: pinned, store: MemoEntityStore(context: context),
                             serviceForAccount: AccountManager(modelContext: context).service(for:))
    }

    static func pin(_ identifier: String, pinned: Bool, store: MemoEntityStore,
                    serviceForAccount: (String) -> (any Service)?) async throws -> MemoEntity {
        guard let memo = try store.memo(for: identifier),
              let service = serviceForAccount(memo.accountKey) else { throw MemoIntentError.notFound }
        _ = try await service.updateMemo(id: memo.id, content: nil, resources: nil, visibility: nil, tags: nil, pinned: pinned)
        await MemoSpotlightIndex.shared.flush()
        guard let entity = try store.entities(for: [identifier]).first else { throw MemoIntentError.notFound }
        return entity
    }
}
