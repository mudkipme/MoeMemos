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
                    persistentIdentifierToken: PersistentIdentifierTokenCoder.encode(storedMemo.id)
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
        MemoryCardView(memo: entry.memo)
    }
}

struct MemoryCardView: View {
    let memo: MemorySnapshot
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
        return formatter.localizedString(for: memo.createdAt, relativeTo: .now)
    }
    
    var attributedString: AttributedString {
        let attributedString = try? AttributedString(markdown: memo.content, options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace))
        
        return attributedString ?? AttributedString(memo.content)
    }

    private var memoURL: URL? {
        guard let persistentId = memo.persistentIdentifierToken else {
            return URL(string: "moememos://memos")
        }

        var components = URLComponents()
        components.scheme = "moememos"
        components.host = "memo"
        components.queryItems = [URLQueryItem(name: "persistent_id", value: persistentId)]
        return components.url
    }
}

struct PinnedMemoryEntry: TimelineEntry {
    let date: Date
    let configuration: PinnedMemoryWidgetConfiguration
    let memo: MemorySnapshot
}

struct PinnedMemoryProvider: AppIntentTimelineProvider {
    func snapshot(for configuration: PinnedMemoryWidgetConfiguration, in context: Context) async -> PinnedMemoryEntry {
        let memo = (try? await getMemo(for: configuration.memo)) ?? sampleMemo
        return PinnedMemoryEntry(date: Date(), configuration: configuration, memo: memo)
    }

    func timeline(for configuration: PinnedMemoryWidgetConfiguration, in context: Context) async -> Timeline<PinnedMemoryEntry> {
        let memo = (try? await getMemo(for: configuration.memo)) ?? sampleMemo
        let frequency = configuration.frequency ?? .daily
        var entries: [PinnedMemoryEntry] = []

        for i in 0..<frequency.memosPerDay {
            let entryDate = Calendar.current.date(byAdding: .hour, value: i * frequency.interval, to: Date())!
            entries.append(PinnedMemoryEntry(date: entryDate, configuration: configuration, memo: memo))
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

    func placeholder(in context: Context) -> PinnedMemoryEntry {
        PinnedMemoryEntry(date: Date(), configuration: PinnedMemoryWidgetConfiguration(), memo: sampleMemo)
    }

    @MainActor
    private func getMemo(for entity: MemoryWidgetMemoEntity?) async throws -> MemorySnapshot? {
        guard
            let entity,
            let memoId = PersistentIdentifierTokenCoder.decode(entity.id)
        else {
            return nil
        }

        let accountManager = AccountManager(modelContext: AppInfo().modelContext)
        guard let service = accountManager.currentService else {
            return nil
        }

        guard let memo = service.memo(id: memoId) else {
            return nil
        }

        return MemorySnapshot(
            content: memo.content,
            createdAt: memo.createdAt,
            persistentIdentifierToken: PersistentIdentifierTokenCoder.encode(memo.id)
        )
    }
}

struct PinnedMemoryEntryView: View {
    var entry: PinnedMemoryProvider.Entry

    var body: some View {
        MemoryCardView(memo: entry.memo)
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

struct PinnedMemoryWidget: Widget {
    let kind: String = "PinnedMemoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PinnedMemoryWidgetConfiguration.self, provider: PinnedMemoryProvider()) { entry in
            PinnedMemoryEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("widget.pinned-memory")
        .description("widget.pinned-memory.description")
        .contentMarginsDisabled()
    }
}
