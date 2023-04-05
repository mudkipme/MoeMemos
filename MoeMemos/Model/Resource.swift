//
//  Resource.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/10.
//

import Foundation

struct Resource: Decodable, Identifiable, Equatable {
    let id: Int
    let createdTs: Date
    let creatorId: Int
    let filename: String
    let size: Int
    let type: String
    let updatedTs: Date
    let externalLink: String?
    let publicId: String?
    
    func path() -> String {
        if let publicId = publicId, !publicId.isEmpty {
            return "/o/r/\(id)/\(publicId)"
        }
        return "/o/r/\(id)/\(filename)"
    }
}
