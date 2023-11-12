//
//  AppInfo.swift
//
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import Observation
import StoreKit

@Observable
public class AppInfo {
    public static let shared = AppInfo()
    public static let groupContainerIdentifier = "group.me.mudkip.MoeMemos"
    public static let keychainAccessGroupName = "AHAQ4D2466.me.mudkip.MoeMemos"
    
    public init() {}
    
    @ObservationIgnored private lazy var region = SKPaymentQueue.default().storefront?.countryCode
    @ObservationIgnored public lazy var website = region == "CHN" ? URL(string: "https://memos.vintage-wiki.com")! : URL(string: "https://memos.moe")!
    @ObservationIgnored public lazy var privacy = region == "CHN" ? URL(string: "https://memos.vintage-wiki.com/privacy")! : URL(string: "https://memos.moe/privacy")!
    @ObservationIgnored public lazy var registration = region == "CHN" ? "晋ICP备2022000288号-2A" : ""
}
