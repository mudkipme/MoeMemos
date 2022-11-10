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
    content: "Make your wonderful dream a reality, and it will become your truth.",
    pinned: false,
    rowStatus: .normal,
    updatedTs: Date(),
    visibility: .private,
    resourceList: nil
)

struct MemoryProvider: IntentTimelineProvider {
    
    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: Date(), configuration: ConfigurationIntent(), memo: sampleMemo)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (MemoryEntry) -> ()) {
        Task { @MainActor in
            let entry = MemoryEntry(date: Date(), configuration: configuration, memo: sampleMemo)
            completion(entry)
        }
    }
    
    func getMemos() async throws -> [Memo]? {
        guard let host = UserDefaults(suiteName: groupContainerIdentifier)?.string(forKey: "memosHost") else {
            return nil
        }
        guard let hostURL = URL(string: host) else {
            return nil
        }
        let memos = Memos(host: hostURL)
        
        let response = try await memos.listMemos(data: MemosListMemo.Input(creatorId: nil, rowStatus: .normal, visibility: nil))
        return [Memo](response.data.shuffled().prefix(4))
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let memos = try? await getMemos()
            var entries = [Entry]()
            
            if let memos = memos {
                for (i, memo) in memos.enumerated() {
                    let entryDate = Calendar.current.date(byAdding: .hour, value: i * 6, to: Date())!
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
    let configuration: ConfigurationIntent
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
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: MemoryProvider()) { entry in
            MemoryEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("Memories")
        .description("Remember your past memos, updates 4 times each day.")
    }
}

struct MemoryWidget_Previews: PreviewProvider {
    static var previews: some View {
        MemoryEntryView(entry: MemoryEntry(date: Date(), configuration: ConfigurationIntent(), memo: sampleMemo))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
