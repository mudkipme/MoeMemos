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
            title: .init(text: .init(localized("whatsnew.title"))),
            features: [
                .init(
                    image: .init(systemName: "arrow.trianglehead.2.clockwise", foregroundColor: .green),
                    title: .init(localized("whatsnew.feature.offline.title")),
                    subtitle: .init(localized("whatsnew.feature.offline.subtitle"))
                ),
                .init(
                    image: .init(systemName: "externaldrive.badge.plus", foregroundColor: .green),
                    title: .init(localized("whatsnew.feature.local.title")),
                    subtitle: .init(localized("whatsnew.feature.local.subtitle"))
                ),
                .init(
                    image: .init(systemName: "wand.and.sparkles", foregroundColor: .green),
                    title: .init(localized("whatsnew.feature.journaling.title")),
                    subtitle: .init(localized("whatsnew.feature.journaling.subtitle"))
                ),
                .init(
                    image: .init(systemName: "paperclip", foregroundColor: .green),
                    title: .init(localized("whatsnew.feature.attachments.title")),
                    subtitle: .init(localized("whatsnew.feature.attachments.subtitle"))
                )
            ],
            primaryAction: .init(
                title: .init(localized("whatsnew.action.continue")),
                backgroundColor: .green,
                foregroundColor: .white
            )
        )
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
