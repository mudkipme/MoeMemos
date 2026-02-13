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
import WhatsNewKit

@MainActor
struct ContentView: View {
    @Environment(AccountViewModel.self) private var accountViewModel: AccountViewModel
    @Environment(AccountManager.self) private var accountManager: AccountManager
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @Environment(AppPath.self) private var appPath: AppPath
    @Injected(\.appInfo) private var appInfo
    @State private var selection: Route? = .memos
    @State private var showingWhatsNew = false
    @Environment(\.scenePhase) var scenePhase
    private let whatsNewVersionStore = UserDefaultsWhatsNewVersionStore()
    
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
                presentWhatsNewIfNeeded()
            }
            .modelContext(appInfo.modelContext)
            .withSheetDestinations(sheetDestinations: $appPath.presentedSheet)
            .sheet(isPresented: $showingWhatsNew) {
                WhatsNewView(
                    whatsNew: whatsNew,
                    versionStore: whatsNewVersionStore
                )
                .interactiveDismissDisabled()
            }
    }
    
    private func loadCurrentUser() async {
        do {
            if accountManager.currentAccount == nil {
                throw MoeMemosError.notLogin
            }
            try await accountViewModel.reloadUsers()
            presentWhatsNewIfNeeded()
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

    private func presentWhatsNewIfNeeded() {
        guard accountManager.currentAccount != nil else {
            return
        }
        guard appPath.presentedSheet == nil else {
            return
        }
        guard !showingWhatsNew else {
            return
        }
        guard !whatsNewVersionStore.hasPresented(whatsNew) else {
            return
        }
        showingWhatsNew = true
    }

    private var whatsNew: WhatsNew {
        WhatsNew(
            version: "2.0.0",
            title: "What's New",
            features: [
                .init(
                    image: .init(systemName: "arrow.trianglehead.2.clockwise", foregroundColor: .green),
                    title: "Offline-first sync",
                    subtitle: "Use Moe Memos offline and sync changes when you're back online."
                ),
                .init(
                    image: .init(systemName: "externaldrive.badge.plus", foregroundColor: .green),
                    title: "Local account support",
                    subtitle: "Create memos without a server and export to a ZIP file."
                ),
                .init(
                    image: .init(systemName: "wand.and.sparkles", foregroundColor: .green),
                    title: "Journaling Suggestions",
                    subtitle: "Choose from suggested moments to start your memo."
                ),
                .init(
                    image: .init(systemName: "paperclip", foregroundColor: .green),
                    title: "Attachment upgrades",
                    subtitle: "Save file attachments beyond images."
                )
            ],
            primaryAction: .init(
                title: "Continue",
                backgroundColor: .green,
                foregroundColor: .white
            )
        )
    }
}
