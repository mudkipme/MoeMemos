//
//  Route.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/10/30.
//

import Foundation

enum Route: Hashable {
    case memos
    case resources
    case archived
    case tag(Tag)
    case settings
}
