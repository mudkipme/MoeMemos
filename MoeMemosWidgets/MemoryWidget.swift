//
//  MemoryWidget.swift
//  MoeMemosWidgetsExtension
//
//  Created by Mudkip on 2022/11/11.
//

import WidgetKit
import SwiftUI
import Intents

let sampleMemo = Memo(
    id: 0,
    createdTs: Date(),
    creatorId: 0,
    creatorName: nil,
    content: "Make your wonderful dream a reality, and it will become your truth.",
    pinned: false,
    rowStatus: .normal,
    updatedTs: Date(),
    visibility: .private,
    resourceList: nil
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

struct MemoryProvider: IntentTimelineProvider {
    
    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: Date(), configuration: MemoryWidgetConfigurationIntent(), memo: sampleMemo)
    }

    func getSnapshot(for configuration: MemoryWidgetConfigurationIntent, in context: Context, completion: @escaping (MemoryEntry) -> ()) {
        Task { @MainActor in
            let entry = MemoryEntry(date: Date(), configuration: configuration, memo: sampleMemo)
            completion(entry)
        }
    }
    
    func getMemos(_ frequency: MemoryUpdatePeriod) async throws -> [Memo]? {
        guard let host = UserDefaults(suiteName: groupContainerIdentifier)?.string(forKey: memosHostKey) else {
            return nil
        }
        guard let hostURL = URL(string: host) else {
            return nil
        }
        
        let openId = UserDefaults(suiteName: groupContainerIdentifier)?.string(forKey: memosOpenIdKey)
        let memos = Memos(host: hostURL, openId: openId)
        
        let response = try await memos.listMemos(data: MemosListMemo.Input(creatorId: nil, rowStatus: .normal, visibility: nil))
        return [Memo](response.data.shuffled().prefix(frequency.memosPerDay))
    }

    func getTimeline(for configuration: MemoryWidgetConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
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
        return formatter.localizedString(for: entry.memo.createdTs, relativeTo: .now)
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
    }
}

struct MemoryWidget_Previews: PreviewProvider {
    static var previews: some View {
        MemoryEntryView(entry: MemoryEntry(date: Date(), configuration: MemoryWidgetConfigurationIntent(), memo: sampleMemo))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
