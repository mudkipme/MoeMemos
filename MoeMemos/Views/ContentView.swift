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
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AppPath.self) private var appPath: AppPath
    @Injected(\.appInfo) private var appInfo
    @State private var selection: Route? = .memos
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        @Bindable var accountViewModel = accountViewModel
        @Bindable var appPath = appPath
        
        Navigation(selection: $selection)
            .environment(appPath)
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
            .withSheetDestinations(sheetDestinations: $appPath.presentedSheet)
    }
    
    private func loadCurrentUser() async {
        do {
            if accountManager.currentAccount == nil {
                throw MoeMemosError.notLogin
            }
            try await accountViewModel.reloadUsers()
        } catch MoeMemosError.notLogin {
            appPath.presentedSheet = .addAccount
        } catch MoeMemosError.accessTokenExpired {
            appPath.presentedSheet = .addAccount
        } catch {
            print(error)
        }
        
        if accountViewModel.users.isEmpty {
            appPath.presentedSheet = .addAccount
        }
    }
}
