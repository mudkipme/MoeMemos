//
//  File.swift
//  
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

public struct Tag: Hashable, Identifiable {
    @Attribute(.unique)
    public var id: UUID = UUID()
    public var name: String
    
    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
