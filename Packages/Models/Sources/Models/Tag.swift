//
//  File.swift
//  
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

@Model
public final class Tag {
    @Attribute(.unique)
    public var id: UUID = UUID()
    public var user: User?
    public var name: String
    public var synced: Bool
    
    public init(id: UUID = UUID(), user: User? = nil, name: String, synced: Bool = false) {
        self.id = id
        self.user = user
        self.name = name
        self.synced = synced
    }
}
