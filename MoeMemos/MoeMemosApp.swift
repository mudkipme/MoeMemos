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
struct MoeMemosApp: App {
    @Injected(\.appInfo) private var appInfo
    @Injected(\.accountViewModel) private var userState
    @Injected(\.accountManager) private var accountManager
    @Injected(\.appPath) private var appPath
    @State private var memosViewModel = MemosViewModel()

    init() {
        AppDependencyManager.shared.add(dependency: Container.shared.accountManager())
        AppDependencyManager.shared.add(dependency: Container.shared.accountViewModel())
        AppDependencyManager.shared.add(dependency: Container.shared.appPath())

        AppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.green)
                .environment(userState)
                .environment(accountManager)
                .environment(appInfo)
                .environment(appPath)
                .environment(memosViewModel)
                .onOpenURL { url in
                    print(url)
                }
        }
    }
}
