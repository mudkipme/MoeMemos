//
//  MoeMemosApp.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import Account

@main
@MainActor
struct MoeMemosApp: App {
    @State private var userState: UserState = .shared
    @State private var accountManager: AccountManager = .shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userState)
                .environment(accountManager)
        }
    }
}
