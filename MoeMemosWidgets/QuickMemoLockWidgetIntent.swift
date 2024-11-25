//
//  QuickMemoLockWidgetIntent.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/25.
//

import SwiftUI
import WidgetKit
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct QuickMemoLockWidgetIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quick Memo Widget Configuration"
    static let description = IntentDescription("Configurate quick memo widget")

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}
