//
//  Route.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/10/30.
//

import SwiftUI
import Models
import Env
import Account
import Factory
import MemoKit
import SwiftData

@MainActor
extension Route {
    @ViewBuilder
    func destination() -> some View {
        switch self {
        case .memos:
            MemosList(tag: nil)
        case .resources:
            Resources()
        case .archived:
            ArchivedMemosList()
        case .tag(let tag):
            MemosList(tag: tag)
        case .settings:
            Settings()
        case .explore:
            Explore()
        case .memosAccount(let accountKey):
            AccountDetailView(accountKey: accountKey)
        case .memo(let memoId):
            MemoView(memoId: memoId)
        }
    }
}

@MainActor
extension View {
    func withSheetDestinations(sheetDestinations: Binding<SheetDestination?>) -> some View {
        sheet(item: sheetDestinations) { destination in
            switch destination {
            case .newMemo:
                MemoEditorSheet(memoId: nil)
                    .withEnvironments()
            case .editMemo(let memoId):
                MemoEditorSheet(memoId: memoId)
                    .withEnvironments()
            case .addAccount:
                AddAccountView()
                    .withEnvironments()
            }
        }
    }
    
    func withEnvironments() -> some View {
        environment(Container.shared.accountViewModel())
            .environment(Container.shared.accountManager())
            .environment(Container.shared.appInfo())
            .environment(Container.shared.appPath())
            .environment(Container.shared.memosViewModel())
    }
}

@MainActor
private struct MemoEditorSheet: View {
    let memoId: PersistentIdentifier?
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel

    var body: some View {
        let memo = memoId.flatMap { id in
            (try? memosViewModel.service)?.memo(id: id)
        }
        MemoEditor(
            memo: memo,
            actions: MemoEditorActions(
                loadTags: {
                    try await memosViewModel.loadTags()
                    return memosViewModel.tags
                },
                createMemo: { content, visibility, resources, tags in
                    try await memosViewModel.createMemo(content: content, visibility: visibility, resources: resources, tags: tags)
                },
                editMemo: { id, content, visibility, resources, tags in
                    try await memosViewModel.editMemo(id: id, content: content, visibility: visibility, resources: resources, tags: tags)
                }
            )
        )
    }
}
