//
//  AppShortcuts.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/19.
//

import AppIntents

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveMemoIntent(),
            phrases: [
                "Save a memo in \(.applicationName)"
            ],
            shortTitle: "Save a memo",
            systemImageName: "square.and.pencil"
        )
    }
}
