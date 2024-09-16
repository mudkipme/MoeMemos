//
//  URL.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/11.
//

import Foundation

extension URL: @retroactive Identifiable {
    public var id: String {
        absoluteString
    }
}
