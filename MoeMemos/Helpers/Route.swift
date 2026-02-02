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
            MemosAccountView(accountKey: accountKey)
        }
    }
}

@MainActor
extension View {
    func withSheetDestinations(sheetDestinations: Binding<SheetDestination?>) -> some View {
        sheet(item: sheetDestinations) { destination in
            switch destination {
            case .newMemo:
                MemoEditorSheet(memo: nil)
                    .withEnvironments()
            case .editMemo(let memo):
                MemoEditorSheet(memo: memo)
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
    let memo: Memo?
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel

    var body: some View {
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
                editMemo: { remoteId, content, visibility, resources, tags in
                    try await memosViewModel.editMemo(remoteId: remoteId, content: content, visibility: visibility, resources: resources, tags: tags)
                }
            )
        )
    }
}
