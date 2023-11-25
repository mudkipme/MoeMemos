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

struct ContentView: View {
    @State private var accountViewModel = AccountViewModel.shared
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Environment(UserState.self) private var userState: UserState
    @State private var selection: Route? = .memos
    @StateObject private var memosViewModel = MemosViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        @Bindable var userState = userState

        Navigation(selection: $selection)
            .tint(.green)
            .sheet(isPresented: $userState.showingLogin) {
                Login()
            }
            .environmentObject(memosViewModel)
            .onChange(of: scenePhase, initial: true, { _, newValue in
                if newValue == .active && userState.currentUser != nil {
                    Task {
                        await loadCurrentUser()
                    }
                }
            })
            .modelContext(AppInfo.shared.modelContext)
            .environment(accountViewModel)
    }
    
    @MainActor
    func loadCurrentUser() async {
        do {
            try await accountViewModel.reloadUsers()
            try await userState.loadCurrentUser()
        } catch {
            print(error)
        }
    }
}
