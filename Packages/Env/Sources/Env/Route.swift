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
    case memo(PersistentIdentifier)
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
    @MainActor
    public var navigationRequest: NavigationRequest?
    
    public init() {}
}

public struct NavigationRequest: Hashable {
    public let root: Route
    public let path: [Route]

    public init(root: Route, path: [Route] = []) {
        self.root = root
        self.path = path
    }
}

public extension Container {
    var appPath: Factory<AppPath> {
        self { AppPath() }.shared
    }
}
