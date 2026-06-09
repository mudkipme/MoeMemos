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
import SwiftData
import UIKit

private enum AppShortcutAction {
    static let newMemoSuffix = ".new-memo"

    static var newMemoType: String {
        "\(Bundle.main.bundleIdentifier ?? "me.mudkip.MoeMemos")\(newMemoSuffix)"
    }

    static func configureShortcutItems() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: newMemoType,
                localizedTitle: NSLocalizedString("input.compose", comment: "Compose"),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(type: .compose),
                userInfo: nil
            )
        ]
    }

    static func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type.hasSuffix(newMemoSuffix) else {
            return false
        }

        Task { @MainActor in
            Container.shared.appPath().presentedSheet = .newMemo
        }
        return true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppShortcutAction.configureShortcutItems()

        guard
            let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
            AppShortcutAction.handle(shortcutItem)
        else {
            return true
        }

        return false
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(AppShortcutAction.handle(shortcutItem))
    }
}

@main
@MainActor
struct MoeMemosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Injected(\.appInfo) private var appInfo
    @Injected(\.accountViewModel) private var userState
    @Injected(\.accountManager) private var accountManager
    @Injected(\.appPath) private var appPath
    @State private var memosViewModel = MemosViewModel()

    init() {
        let accountManager = Container.shared.accountManager()
        let accountViewModel = Container.shared.accountViewModel()
        let appPath = Container.shared.appPath()

        AppDependencyManager.shared.add(dependency: accountManager)
        AppDependencyManager.shared.add(dependency: accountViewModel)
        AppDependencyManager.shared.add(dependency: appPath)

        AppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.green)
                .withEnvironments()
                .onOpenURL { url in
                    if let tagName = MemoTagMarkdownPreprocessor.tagName(from: url) {
                        appPath.navigationRequest = NavigationRequest(push: .tag(Tag(name: tagName)))
                        return
                    }

                    if url.host() == "new-memo" {
                        appPath.presentedSheet = .newMemo
                        return
                    }

                    if url.host() == "memos" {
                        appPath.navigationRequest = NavigationRequest(root: .memos)
                        return
                    }

                    if url.host() == "memo" {
                        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        let encodedIdentifier = components?.queryItems?.first(where: { $0.name == "persistent_id" })?.value
                        guard
                            let encodedIdentifier,
                            !encodedIdentifier.isEmpty,
                            let persistentIdentifier = PersistentIdentifierTokenCoder.decode(encodedIdentifier)
                        else {
                            return
                        }
                        appPath.navigationRequest = NavigationRequest(root: .memos, path: [.memo(persistentIdentifier)])
                    }
                }
        }
    }
}
