//
//  Route.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/10/30.
//

import Models
import Observation
import Factory
import SwiftData

public enum Route: Hashable {
    case memos
    case resources
    case archived
    case tag(Tag)
    case settings
    case explore
    case memosAccount(String)
}

public enum SheetDestination: Identifiable, Hashable {
    case newMemo
    case editMemo(PersistentIdentifier)
    case addAccount
    
    public var id: String {
        switch self {
        case .newMemo:
            return "newMemo"
        case .editMemo:
            return "editMemo"
        case .addAccount:
            return "addAccount"
        }
    }
}

@Observable public final class AppPath: Sendable {
    @MainActor
    public var presentedSheet: SheetDestination?
    
    public init() {}
}

public extension Container {
    var appPath: Factory<AppPath> {
        self { AppPath() }.shared
    }
}
