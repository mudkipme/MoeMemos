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

struct Provider: @preconcurrency IntentTimelineProvider {
    func placeholder(in context: Context) -> MemosGraphEntry {
        MemosGraphEntry(date: Date(), configuration: MemosGraphWidgetConfigurationIntent(), matrix: nil)
    }

    @MainActor
    func getSnapshot(for configuration: MemosGraphWidgetConfigurationIntent, in context: Context, completion: @escaping (MemosGraphEntry) -> ()) {
        Task {
            var matrix: [DailyUsageStat]?
            if !context.isPreview {
                matrix = try? await getMatrix()
            }
            
            let entry = MemosGraphEntry(date: Date(), configuration: configuration, matrix: matrix)
            completion(entry)
        }
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

    @MainActor
    func getTimeline(for configuration: MemosGraphWidgetConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let matrix = try? await getMatrix()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            let entry = MemosGraphEntry(date: entryDate, configuration: configuration, matrix: matrix)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct MemosGraphEntry: TimelineEntry {
    let date: Date
    let configuration: MemosGraphWidgetConfigurationIntent
    let matrix: [DailyUsageStat]?
}

struct MemosGraphEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Heatmap(matrix: entry.matrix ?? DailyUsageStat.initialMatrix, alignment: .center)
            .padding()
    }
}

struct MemosGraphWidget: Widget {
    let kind: String = "MemosGraphWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: MemosGraphWidgetConfigurationIntent.self, provider: Provider()) { entry in
            MemosGraphEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("widget.memo-graph")
        .description("widget.memo-graph.description")
        .contentMarginsDisabled()
    }
}

struct MemosGraphWidget_Previews: PreviewProvider {
    static var previews: some View {
        MemosGraphEntryView(entry: MemosGraphEntry(date: Date(), configuration: MemosGraphWidgetConfigurationIntent(), matrix: nil))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
