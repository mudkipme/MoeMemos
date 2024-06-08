//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import Models
import MemosService
import SwiftData
import Account
import Factory

struct ContentView: View {
    @Environment(AccountViewModel.self) private var accountViewModel: AccountViewModel
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Injected(\.appInfo) private var appInfo
    @State private var selection: Route? = .memos
    @State private var memosViewModel = MemosViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        Navigation(selection: $selection)
            .tint(.green)
            .environment(memosViewModel)
            .onChange(of: scenePhase, initial: true, { _, newValue in
                if newValue == .active {
                    Task {
                        await loadCurrentUser()
                    }
                }
            })
            .modelContext(appInfo.modelContext)
    }
    
    @MainActor
    func loadCurrentUser() async {
        do {
            try await accountViewModel.reloadUsers()
        } catch {
            print(error)
        }
    }
}
