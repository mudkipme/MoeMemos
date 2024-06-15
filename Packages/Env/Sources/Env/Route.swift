//
//  Route.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/10/30.
//

import Models

public enum Route: Hashable {
    case memos
    case resources
    case archived
    case tag(Tag)
    case settings
    case explore
    case memosAccount(String)
}
