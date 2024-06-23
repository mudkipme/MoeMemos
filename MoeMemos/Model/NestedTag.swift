//
//  NestedTag.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/6/23.
//

import Foundation
import Models

struct NestedTag: Identifiable, Hashable {
    var id: String { fullName }
    var fullName: String
    var name: String
    var children: [NestedTag]? = nil
    
    static func fromTagList(_ tagList: [String], prefix: String? = nil) -> [NestedTag] {
        var tagDict = [String: [String]]()
        
        for tag in tagList {
            let parts = tag.split(separator: "/", maxSplits: 2).map(String.init)
            if tagDict[parts[0]] == nil {
                tagDict[parts[0]] = []
            }
            
            if parts.count > 1 {
                tagDict[parts[0]]?.append(parts[1])
            }
        }
        
        var nestedTags = [NestedTag]()
        for (key, value) in tagDict {
            let fullName = prefix != nil ? "\(prefix!)/\(key)" : key
            let children = fromTagList(value, prefix: fullName)
            let tag = NestedTag(fullName: fullName, name: key, children: children.isEmpty ? nil : children)
            nestedTags.append(tag)
        }
        
        return nestedTags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
