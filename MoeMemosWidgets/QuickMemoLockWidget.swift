//
//  QuickMemoLockWidget.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/25.
//

import WidgetKit
import SwiftUI
import Intents
import KeychainSwift
import Models
import Account

struct QuickMemoLockWidgetProvider: AppIntentTimelineProvider {
    func snapshot(for configuration: QuickMemoLockWidgetIntent, in context: Context) async -> QuickMemoEntry {
        return QuickMemoEntry(date: Date())
    }
    
    func timeline(for configuration: QuickMemoLockWidgetIntent, in context: Context) async -> Timeline<QuickMemoEntry> {
        let entry = QuickMemoEntry(date: Date())
        return Timeline(entries: [entry], policy: .atEnd)
    }
    
    func placeholder(in context: Context) -> QuickMemoEntry {
        QuickMemoEntry(date: Date())
    }
}

struct QuickMemoEntry: TimelineEntry {
    let date: Date
}

struct QuickMemoLockWidgetView : View {
    var body: some View {
        ZStack{
            AccessoryWidgetBackground()
            Image("MoeMemos")
                .clipShape(.circle)
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "moememos://new-memo"))
    }
}

struct QuickMemoLockWidget: Widget {
    let kind: String = "QuickMemoLockWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickMemoLockWidgetIntent.self, provider: QuickMemoLockWidgetProvider()) { entry in
            QuickMemoLockWidgetView()
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
        .configurationDisplayName("Quick Memo")
        .description("Quick Memo Widget")
    }
}
