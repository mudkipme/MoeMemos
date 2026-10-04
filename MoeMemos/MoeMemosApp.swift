//
//  MoeMemosApp.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import MemoSystem
import MemoData
import SwiftUI
import Account
import Models
import Factory
import AppIntents
import Env
import SwiftData
import UIKit
import CoreSpotlight

struct MoeMemosIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [MemoIntentsPackage.self] }
}

private enum AppShortcutAction {
    static let newMemoSuffix = ".new-memo"

    static var newMemoType: String {
        "\(Bundle.main.bundleIdentifier ?? "me.mudkip.MoeMemos")\(newMemoSuffix)"
    }

    @MainActor
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

    @MainActor
    static func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type.hasSuffix(newMemoSuffix) else {
            return false
        }

        Container.shared.appPath().presentedSheet = .newMemo
        return true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppShortcutAction.configureShortcutItems()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let shortcutItem = connectionOptions.shortcutItem else {
            return
        }
        _ = AppShortcutAction.handle(shortcutItem)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
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
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MemoSpotlightIndex.shared.startObserving()
        let accountManager = Container.shared.accountManager()
        let accountViewModel = Container.shared.accountViewModel()
        let appPath = Container.shared.appPath()

        AppDependencyManager.shared.add(dependency: accountManager)
        AppDependencyManager.shared.add(dependency: accountViewModel)
        AppDependencyManager.shared.add(dependency: appPath)
        AppDependencyManager.shared.add(dependency: MemoNavigator { identifier in
            try Self.navigateToMemo(identifier: identifier, accountManager: accountManager, appPath: appPath,
                                    context: Container.shared.appInfo().modelContext)
        })

        AppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.green)
                .withEnvironments()
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await MemoSpotlightIndex.shared.rebuild(container: appInfo.modelContext.container)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                    openMemo(identifier: identifier)
                }
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
                        if let identifier = components?.queryItems?.first(where: { $0.name == "entity_id" })?.value {
                            openMemo(identifier: identifier)
                            return
                        }
                        let encodedIdentifier = components?.queryItems?.first(where: { $0.name == "persistent_id" })?.value
                        guard
                            let encodedIdentifier,
                            !encodedIdentifier.isEmpty,
                            let entity = try? MemoEntityStore(context: appInfo.modelContext).entity(forLegacyIdentifier: encodedIdentifier)
                        else {
                            return
                        }
                        openMemo(identifier: entity.id)
                    }
                }
        }
    }

    private func openMemo(identifier: String) {
        try? Self.navigateToMemo(identifier: identifier, accountManager: accountManager,
                                appPath: appPath, context: appInfo.modelContext)
    }

    private static func navigateToMemo(identifier: String, accountManager: AccountManager,
                                       appPath: AppPath, context: ModelContext) throws {
        guard let memo = try MemoEntityStore(context: context).memo(for: identifier) else { throw MemoIntentError.notFound }
        if accountManager.currentAccount?.key != memo.accountKey {
            try accountManager.selectAccount(key: memo.accountKey)
        }
        appPath.presentedSheet = nil
        appPath.navigationRequest = NavigationRequest(root: .memos, path: [.memo(memo.id)])
    }
}
