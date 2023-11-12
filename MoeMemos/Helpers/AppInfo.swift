//
//  AppInfo.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import StoreKit

class AppInfo: ObservableObject {
    lazy var region = SKPaymentQueue.default().storefront?.countryCode
    lazy var website = region == "CHN" ? URL(string: "https://memos.vintage-wiki.com")! : URL(string: "https://memos.moe")!
    lazy var privacy = region == "CHN" ? URL(string: "https://memos.vintage-wiki.com/privacy")! : URL(string: "https://memos.moe/privacy")!
    lazy var registration = region == "CHN" ? "晋ICP备2022000288号-2A" : ""
}
