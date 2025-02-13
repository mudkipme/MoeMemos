//
//  MemosGraphWidgetConfiguration.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/24.
//

import Foundation
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MemosGraphWidgetConfiguration: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    static let intentClassName = "MemosGraphWidgetConfigurationIntent"

    static let title: LocalizedStringResource = "Memos Graph Widget Configuration"
    static let description = IntentDescription("Configurate memos graph widget")

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        // TODO: Place your refactored intent handler code here.
        return .result()
    }
}


