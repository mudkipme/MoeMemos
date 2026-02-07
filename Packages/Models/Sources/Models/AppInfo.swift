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
        let storeURL = groupURL.appendingPathComponent("MoeMemos_20260207.store", isDirectory: false)

        let configuration = ModelConfiguration(url: storeURL)
        let container = try! ModelContainer(for: User.self, StoredMemo.self, StoredResource.self, configurations: configuration)
        modelContext = ModelContext(container)
    }
    
    @ObservationIgnored public lazy var website = URL(string: "https://memos.moe")!
    @ObservationIgnored public lazy var privacy = URL(string: "https://memos.moe/privacy")!
    @ObservationIgnored public lazy var registration = ""
}

public extension Container {
    var appInfo: Factory<AppInfo> {
        self { AppInfo() }.shared
    }
}
