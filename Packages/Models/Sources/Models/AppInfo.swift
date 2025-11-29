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
        let container = try! ModelContainer(
            for: User.self,
            configurations: .init(groupContainer: .identifier(AppInfo.groupContainerIdentifier))
        )
        modelContext = ModelContext(container)
    }
    
    @ObservationIgnored private lazy var region = SKPaymentQueue.default().storefront?.countryCode
//    @ObservationIgnored public lazy var website = region == "CHN" ? URL(string: "https://memos.vintage-wiki.com")! : URL(string: "https://memos.littledaemon.dev")!
//    @ObservationIgnored public lazy var privacy = region == "CHN" ? URL(string: "https://memos.vintage-wiki.com/privacy")! : URL(string: "https://memos.littledaemon.dev/privacy")!
//    @ObservationIgnored public lazy var registration = region == "CHN" ? "" : ""
    @ObservationIgnored public lazy var website = URL(string: "https://memos.littledaemon.dev")!
    @ObservationIgnored public lazy var privacy = URL(string: "https://memos.littledaemon.dev/privacy")!
    @ObservationIgnored public lazy var registration = ""
}

public extension Container {
    var appInfo: Factory<AppInfo> {
        self { AppInfo() }.shared
    }
}
