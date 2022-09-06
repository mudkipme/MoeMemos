//
//  MoeMemosApp.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI

@main
struct MoeMemosApp: App {
    @StateObject private var memosViewModel = MemosViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(memosViewModel)
        }
    }
}
