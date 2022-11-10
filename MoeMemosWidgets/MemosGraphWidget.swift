//
//  MemosGraphWidget.swift
//  MemosGraphWidget
//
//  Created by Mudkip on 2022/11/11.
//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> MemosGraphEntry {
        MemosGraphEntry(date: Date(), configuration: ConfigurationIntent(), matrix: nil)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (MemosGraphEntry) -> ()) {
        Task { @MainActor in
            var matrix: [DailyUsageStat]?
            if !context.isPreview {
                matrix = try? await getMatrix()
            }
            
            let entry = MemosGraphEntry(date: Date(), configuration: configuration, matrix: matrix)
            completion(entry)
        }
    }
    
    func getMatrix() async throws -> [DailyUsageStat]? {
        guard let host = UserDefaults(suiteName: groupContainerIdentifier)?.string(forKey: "memosHost") else {
            return nil
        }
        guard let hostURL = URL(string: host) else {
            return nil
        }
        let memos = Memos(host: hostURL)
        
        let response = try await memos.listMemos(data: MemosListMemo.Input(creatorId: nil, rowStatus: .normal, visibility: nil))
        return DailyUsageStat.calculateMatrix(memoList: response.data)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
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
    let configuration: ConfigurationIntent
    let matrix: [DailyUsageStat]?
}

struct MoeMemosWidgetsEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Heatmap(matrix: entry.matrix ?? DailyUsageStat.initialMatrix)
            .padding()
    }
}

struct MemosGraphWidget: Widget {
    let kind: String = "MemosGraphWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            MoeMemosWidgetsEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Memos Graph")
        .description("The graph to display how much memos you composed every day in recent weeks, updates hourly.")
    }
}

struct MemosGraphWidget_Previews: PreviewProvider {
    static var previews: some View {
        MoeMemosWidgetsEntryView(entry: MemosGraphEntry(date: Date(), configuration: ConfigurationIntent(), matrix: nil))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
