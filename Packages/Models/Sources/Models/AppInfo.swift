//
//  AppInfo.swift
//
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import Observation
import StoreKit
import SwiftData
import Factory

@Observable public class AppInfo {
    public static let groupContainerIdentifier = "group.me.mudkip.MoeMemos"
    public static let keychainAccessGroupName = "AHAQ4D2466.me.mudkip.MoeMemos"
    
    @ObservationIgnored public let modelContext: ModelContext
    
    public init() {
        let fileManager = FileManager.default
        let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppInfo.groupContainerIdentifier)!
        let storeURL = groupURL.appendingPathComponent("MoeMemos.store", isDirectory: false)

        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["MOEMEMOS_WIPE_STORE"] == "1" || ProcessInfo.processInfo.arguments.contains("--wipe-store") {
            try? fileManager.removeItem(at: storeURL)
        }
        #endif

        let configuration = ModelConfiguration(url: storeURL)
        let container = try! ModelContainer(for: User.self, StoredMemo.self, StoredResource.self, configurations: configuration)
        modelContext = ModelContext(container)
    }
    
    @ObservationIgnored private lazy var region = SKPaymentQueue.default().storefront?.countryCode
    @ObservationIgnored public lazy var website = URL(string: "https://memos.moe")!
    @ObservationIgnored public lazy var privacy = URL(string: "https://memos.moe/privacy")!
    @ObservationIgnored public lazy var registration = ""
}

public extension Container {
    var appInfo: Factory<AppInfo> {
        self { AppInfo() }.shared
    }
}
