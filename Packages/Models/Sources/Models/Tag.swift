//
//  File.swift
//  
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

public struct Tag: Hashable, Identifiable {
    public var name: String
    public var id: String { name }
    
    public init(name: String) {
        self.name = name
    }
}

@Model
public final class TagModel {
    #Unique<TagModel>([\.user, \.name])
    public var user: User?
    public var name: String
    
    @Relationship(inverse: \MemoModel.tags)
    public var memos: [MemoModel]
    
    public init(user: User? = nil, name: String, memos: [MemoModel] = []) {
        self.user = user
        self.name = name
        self.memos = memos
    }
}
