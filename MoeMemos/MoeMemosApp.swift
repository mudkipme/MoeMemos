//
//  MoeMemosApp.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI

@main
struct MoeMemosApp: App {
    @StateObject private var userState: UserState = .shared
    @StateObject private var memosManager: MemosManager = .shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userState)
                .environmentObject(memosManager)
        }
    }
}
