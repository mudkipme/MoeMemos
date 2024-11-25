//
//  MemosGraphWidget.swift
//  MemosGraphWidget
//
//  Created by Mudkip on 2022/11/11.
//

import WidgetKit
import SwiftUI
import Intents
import KeychainSwift
import Models
import Account

struct Provider: AppIntentTimelineProvider {
    func snapshot(for configuration: MemosGraphWidgetConfiguration, in context: Context) async -> MemosGraphEntry {
        var matrix: [DailyUsageStat]?
        if !context.isPreview {
            matrix = try? await getMatrix()
        }
        
        return MemosGraphEntry(date: Date(), configuration: configuration, matrix: matrix)
    }
    
    func timeline(for configuration: MemosGraphWidgetConfiguration, in context: Context) async -> Timeline<MemosGraphEntry> {
        let matrix = try? await getMatrix()
        let entryDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let entry = MemosGraphEntry(date: entryDate, configuration: configuration, matrix: matrix)
        return Timeline(entries: [entry], policy: .atEnd)
    }
    
    func placeholder(in context: Context) -> MemosGraphEntry {
        MemosGraphEntry(date: Date(), configuration: MemosGraphWidgetConfiguration(), matrix: nil)
    }
    
    @MainActor
    func getMatrix() async throws -> [DailyUsageStat]? {
        let accountManager = AccountManager()
        guard let memos = accountManager.currentService else {
            return nil
        }
        
        let response = try await memos.listMemos()
        return DailyUsageStat.calculateMatrix(memoList: response)
    }
}

struct MemosGraphEntry: TimelineEntry {
    let date: Date
    let configuration: MemosGraphWidgetConfiguration
    let matrix: [DailyUsageStat]?
}

struct MemosGraphEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Heatmap(matrix: entry.matrix ?? DailyUsageStat.initialMatrix, alignment: .center)
            .padding()
            .containerBackground(.background, for: .widget)
    }
}

struct MemosGraphWidget: Widget {
    let kind: String = "MemosGraphWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MemosGraphWidgetConfiguration.self, provider: Provider()) { entry in
            MemosGraphEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("widget.memo-graph")
        .description("widget.memo-graph.description")
        .contentMarginsDisabled()
    }
}
