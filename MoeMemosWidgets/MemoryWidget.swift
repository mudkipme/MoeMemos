//
//  MemoryWidget.swift
//  MoeMemosWidgetsExtension
//
//  Created by Mudkip on 2022/11/11.
//

import WidgetKit
import SwiftUI
import Intents
import KeychainSwift
import Models
import Account

let sampleMemo = Memo(
    content: "Make your wonderful dream a reality, and it will become your truth.",
    createdAt: .now
)

extension MemoryUpdatePeriod {
    var memosPerDay: Int {
        switch self {
        case .daily: return 1
        case .hourly: return 24
        default: return 4
        }
    }
    
    var interval: Int {
        return 24 / memosPerDay
    }
}

struct MemoryProvider: @preconcurrency IntentTimelineProvider {
    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: Date(), configuration: MemoryWidgetConfigurationIntent(), memo: sampleMemo)
    }

    @MainActor
    func getSnapshot(for configuration: MemoryWidgetConfigurationIntent, in context: Context, completion: @escaping (MemoryEntry) -> ()) {
        Task {
            let entry = MemoryEntry(date: Date(), configuration: configuration, memo: sampleMemo)
            completion(entry)
        }
    }
    
    @MainActor
    func getMemos(_ frequency: MemoryUpdatePeriod) async throws -> [Memo]? {
        let accountManager = AccountManager()
        guard let memos = accountManager.currentService else { return nil }
        
        let response = try await memos.listMemos()
        return [Memo](response.shuffled().prefix(frequency.memosPerDay))
    }

    @MainActor
    func getTimeline(for configuration: MemoryWidgetConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let memos = try? await getMemos(configuration.frequency)
            var entries = [Entry]()
            
            if let memos = memos {
                for (i, memo) in memos.enumerated() {
                    let entryDate = Calendar.current.date(byAdding: .hour, value: i * configuration.frequency.interval, to: Date())!
                    entries.append(MemoryEntry(date: entryDate, configuration: configuration, memo: memo))
                }
            } else {
                let entryDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
                entries.append(MemoryEntry(date: entryDate, configuration: configuration, memo: sampleMemo))
            }
            
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
}

struct MemoryEntry: TimelineEntry {
    let date: Date
    let configuration: MemoryWidgetConfigurationIntent
    let memo: Memo
}

struct MemoryEntryView : View {
    var entry: MemoryProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading) {
            Text(dateString)
                .font(.footnote)
                .foregroundColor(.secondary)
            HStack {
                Spacer()
            }
            Text(attributedString)
                .font(family == .systemSmall ? .caption : .body)
            Spacer()
        }
        .padding()
        
    }
    
    var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: entry.memo.createdAt, relativeTo: .now)
    }
    
    var attributedString: AttributedString {
        let attributedString = try? AttributedString(markdown: entry.memo.content, options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace))
        
        return attributedString ?? AttributedString(entry.memo.content)
    }
}

struct MemoryWidget: Widget {
    let kind: String = "MemoryWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: MemoryWidgetConfigurationIntent.self, provider: MemoryProvider()) { entry in
            MemoryEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("widget.memories")
        .description("widget.memories.description")
        .contentMarginsDisabled()
    }
}

struct MemoryWidget_Previews: PreviewProvider {
    static var previews: some View {
        MemoryEntryView(entry: MemoryEntry(date: Date(), configuration: MemoryWidgetConfigurationIntent(), memo: sampleMemo))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
