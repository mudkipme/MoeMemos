//
//  MemoryUpdatePeriodAppEnum.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/24.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum MemoryUpdatePeriodAppEnum: String, AppEnum {
    case daily
    case hourly
    case quartern

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Memory Update Frequency")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .daily: "Daily",
        .hourly: "Hourly",
        .quartern: "4 times per day"
    ]
}

