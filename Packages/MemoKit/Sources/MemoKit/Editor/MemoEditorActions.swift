import Models

public struct MemoEditorActions {
    public let loadTags: @MainActor () async throws -> [Tag]
    public let createMemo: @MainActor (_ content: String, _ visibility: MemoVisibility, _ resources: [Resource], _ tags: [String]?) async throws -> Void
    public let editMemo: @MainActor (_ remoteId: String, _ content: String, _ visibility: MemoVisibility, _ resources: [Resource], _ tags: [String]?) async throws -> Void

    public init(
        loadTags: @escaping @MainActor () async throws -> [Tag],
        createMemo: @escaping @MainActor (_ content: String, _ visibility: MemoVisibility, _ resources: [Resource], _ tags: [String]?) async throws -> Void,
        editMemo: @escaping @MainActor (_ remoteId: String, _ content: String, _ visibility: MemoVisibility, _ resources: [Resource], _ tags: [String]?) async throws -> Void
    ) {
        self.loadTags = loadTags
        self.createMemo = createMemo
        self.editMemo = editMemo
    }
}
