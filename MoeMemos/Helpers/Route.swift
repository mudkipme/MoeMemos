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
                MemoInput(memo: nil)
            case .editMemo(let memo):
                MemoInput(memo: memo)
            case .addAccount:
                AddAccountView()
            }
        }
    }
}
