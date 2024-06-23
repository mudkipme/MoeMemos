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
