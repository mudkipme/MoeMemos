//
//  MoeMemosApp.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import Account
import Models
import Factory
import AppIntents
import Env

@main
struct MoeMemosApp: App {
    @Injected(\.appInfo) private var appInfo
    @Injected(\.accountViewModel) private var userState
    @Injected(\.accountManager) private var accountManager
    @Injected(\.appPath) private var appPath
    @State private var memosViewModel = MemosViewModel()

    init() {
        AppDependencyManager.shared.add(dependency: Container.shared.accountManager())
        AppDependencyManager.shared.add(dependency: Container.shared.accountViewModel())
        AppDependencyManager.shared.add(dependency: Container.shared.appPath())

        AppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.green)
                .withEnvironments()
                .onOpenURL { url in
                    if url.host() == "new-memo" {
                        appPath.presentedSheet = .newMemo
                    } else if url.host() == "edit-memo" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                            Task {
                                do {
                                    let memo = try await memosViewModel.getMemo(remoteId: id)
                                    appPath.presentedSheet = .editMemo(memo)
                                } catch {
                                    // ignore
                                }
                            }
                        }
                    }
                }
        }
    }
}
