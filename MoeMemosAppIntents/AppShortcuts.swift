//
//  AppShortcuts.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/19.
//

import MemoSystem
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
        AppShortcut(
            intent: FindMemosIntent(),
            phrases: ["Find memos in \(.applicationName)"],
            shortTitle: "Find memos",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: OpenMemoIntent(),
            phrases: ["Open a memo in \(.applicationName)"],
            shortTitle: "Open memo",
            systemImageName: "note.text"
        )
        AppShortcut(
            intent: AppendToMemoIntent(),
            phrases: ["Append to a memo in \(.applicationName)"],
            shortTitle: "Append to memo",
            systemImageName: "text.append"
        )
        AppShortcut(
            intent: PinMemoIntent(),
            phrases: ["Pin a memo in \(.applicationName)"],
            shortTitle: "Pin memo",
            systemImageName: "pin"
        )
    }
}
