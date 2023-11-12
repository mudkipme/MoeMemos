//
//  Route.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/10/30.
//

import SwiftUI

@MainActor
enum Route: Hashable {
    case memos
    case resources
    case archived
    case tag(Tag)
    case settings
    case explore
    
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
        }
    }
}
