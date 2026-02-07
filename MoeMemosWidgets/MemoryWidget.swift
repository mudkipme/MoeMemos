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

struct MemorySnapshot: Sendable {
    let content: String
    let createdAt: Date
    let persistentIdentifierToken: String?
}

private let sampleMemo = MemorySnapshot(
    content: "Make your wonderful dream a reality, and it will become your truth.",
    createdAt: .now,
    persistentIdentifierToken: nil
)

private func encodePersistentIdentifier(_ identifier: some Encodable) -> String? {
    guard let encoded = try? JSONEncoder().encode(identifier) else {
        return nil
    }
    return encoded.base64EncodedString()
}

extension MemoryUpdatePeriodAppEnum {
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

struct MemoryProvider: AppIntentTimelineProvider {
    func snapshot(for configuration: MemoryWidgetConfiguration, in context: Context) async -> MemoryEntry {
        return MemoryEntry(date: Date(), configuration: configuration, memo: sampleMemo)
    }
    
    func timeline(for configuration: MemoryWidgetConfiguration, in context: Context) async -> Timeline<MemoryEntry> {
        let memos = try? await getMemos(configuration.frequency ?? .daily)
        var entries = [Entry]()
        
        if let memos = memos {
            for (i, memo) in memos.enumerated() {
                let entryDate = Calendar.current.date(byAdding: .hour, value: i * (configuration.frequency ?? .daily).interval, to: Date())!
                entries.append(MemoryEntry(date: entryDate, configuration: configuration, memo: memo))
            }
        } else {
            let entryDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            entries.append(MemoryEntry(date: entryDate, configuration: configuration, memo: sampleMemo))
        }
        
        return Timeline(entries: entries, policy: .atEnd)
    }
    
    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: Date(), configuration: MemoryWidgetConfiguration(), memo: sampleMemo)
    }

    func getMemos(_ frequency: MemoryUpdatePeriodAppEnum) async throws -> [MemorySnapshot]? {
        try await loadMemosFromStore(frequency: frequency)
    }

    @MainActor
    private func loadMemosFromStore(frequency: MemoryUpdatePeriodAppEnum) async throws -> [MemorySnapshot]? {
        let accountManager = AccountManager(modelContext: AppInfo().modelContext)
        let memos = accountManager.currentService
        guard let memos else { return nil }
        
        let response = try await memos.listMemos()
        return response
            .shuffled()
            .prefix(frequency.memosPerDay)
            .map { storedMemo in
                MemorySnapshot(
                    content: storedMemo.content,
                    createdAt: storedMemo.createdAt,
                    persistentIdentifierToken: encodePersistentIdentifier(storedMemo.id)
                )
            }
    }
}

struct MemoryEntry: TimelineEntry {
    let date: Date
    let configuration: MemoryWidgetConfiguration
    let memo: MemorySnapshot
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
        .containerBackground(.background, for: .widget)
        .widgetURL(memoURL)
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

    private var memoURL: URL? {
        guard let persistentId = entry.memo.persistentIdentifierToken else {
            return URL(string: "moememos://memos")
        }

        var components = URLComponents()
        components.scheme = "moememos"
        components.host = "memo"
        components.queryItems = [URLQueryItem(name: "persistent_id", value: persistentId)]
        return components.url
    }
}

struct MemoryWidget: Widget {
    let kind: String = "MemoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MemoryWidgetConfiguration.self, provider: MemoryProvider()) { entry in
            MemoryEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("widget.memories")
        .description("widget.memories.description")
        .contentMarginsDisabled()
    }
}
