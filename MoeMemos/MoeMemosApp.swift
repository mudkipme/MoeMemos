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

@main
struct MoeMemosApp: App {
    @Injected(\.appInfo) private var appInfo
    @Injected(\.accountViewModel) private var userState
    @Injected(\.accountManager) private var accountManager
    
    init() {
        AppDependencyManager.shared.add(dependency: Container.shared.accountManager())
        AppDependencyManager.shared.add(dependency: Container.shared.accountViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userState)
                .environment(accountManager)
                .environment(appInfo)
        }
    }
}
