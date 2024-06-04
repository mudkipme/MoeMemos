//
//  MoeMemosApp.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import Account
import Models

@main
@MainActor
struct MoeMemosApp: App {
    @State private var userState: AccountViewModel = AccountViewModel(currentContext: AppInfo.shared.modelContext, accountManager: .shared)
    @State private var accountManager: AccountManager = .shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userState)
                .environment(accountManager)
        }
    }
}
