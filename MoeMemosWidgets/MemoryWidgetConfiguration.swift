//
//  MemoryWidgetConfiguration.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/24.
//

import Foundation
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MemoryWidgetConfiguration: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    static let intentClassName = "MemoryWidgetConfigurationIntent"

    static let title: LocalizedStringResource = "Memory Widget Configuration"
    static let description = IntentDescription("Configurate how the memory widget is updated")

    @Parameter(title: "Update")
    var frequency: MemoryUpdatePeriodAppEnum?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        // TODO: Place your refactored intent handler code here.
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
    static func frequencyParameterDisambiguationIntro(count: Int, frequency: MemoryUpdatePeriodAppEnum) -> Self {
        "There are \(count) options matching ‘\(frequency)’."
    }
    static func frequencyParameterConfirmation(frequency: MemoryUpdatePeriodAppEnum) -> Self {
        "Just to confirm, you wanted ‘\(frequency)’?"
    }
}

