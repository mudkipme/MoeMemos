//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import Models
import SwiftData
import Account
import Factory
import Env

@MainActor
struct ContentView: View {
    @Environment(AccountViewModel.self) private var accountViewModel: AccountViewModel
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Injected(\.appInfo) private var appInfo
    @State private var selection: Route? = .memos
    @State private var memosViewModel = MemosViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        @Bindable var accountViewModel = accountViewModel
        
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
            .task {
                await loadCurrentUser()
            }
            .task(id: accountManager.currentAccount) {
                try? await memosViewModel.loadMemos()
                try? await memosViewModel.loadTags()
            }
            .modelContext(appInfo.modelContext)
            .sheet(isPresented: $accountViewModel.showingAddAccount) {
                AddAccountView()
                    .tint(.green)
            }
    }
    
    private func loadCurrentUser() async {
        do {
            if accountManager.currentAccount == nil {
                throw MoeMemosError.notLogin
            }
            try await accountViewModel.reloadUsers()
        } catch MoeMemosError.notLogin {
            accountViewModel.showingAddAccount = true
        } catch {
            print(error)
        }
    }
}
