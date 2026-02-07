//
//  MoeMemosApp.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import Account
import Models
import Factory
import AppIntents
import Env

@main
@MainActor
struct MoeMemosApp: App {
    @Injected(\.appInfo) private var appInfo
    @Injected(\.accountViewModel) private var userState
    @Injected(\.accountManager) private var accountManager
    @Injected(\.appPath) private var appPath
    @State private var memosViewModel = MemosViewModel()

    init() {
        let accountManager = Container.shared.accountManager()
        let accountViewModel = Container.shared.accountViewModel()
        let appPath = Container.shared.appPath()

        AppDependencyManager.shared.add(dependency: accountManager)
        AppDependencyManager.shared.add(dependency: accountViewModel)
        AppDependencyManager.shared.add(dependency: appPath)

        AppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.green)
                .withEnvironments()
                .onOpenURL { url in
                    if url.host() == "new-memo" {
                        appPath.presentedSheet = .newMemo
                        return
                    }

                    if url.host() == "memos" {
                        appPath.pendingMemoPersistentIdentifier = nil
                        return
                    }

                    if url.host() == "memo" {
                        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        let persistentIdentifier = components?.queryItems?.first(where: { $0.name == "persistent_id" })?.value
                        guard let persistentIdentifier, !persistentIdentifier.isEmpty else {
                            return
                        }
                        appPath.pendingMemoPersistentIdentifier = persistentIdentifier
                    }
                }
        }
    }
}
