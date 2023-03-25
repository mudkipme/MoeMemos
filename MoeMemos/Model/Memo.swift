//
//  Memo.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import Foundation
import SwiftUI

enum MemosVisibility: String, Decodable, Encodable, CaseIterable {
    case `public` = "PUBLIC"
    case `protected` = "PROTECTED"
    case `private` = "PRIVATE"
}

enum MemosRowStatus: String, Decodable, Encodable {
    case normal = "NORMAL"
    case archived = "ARCHIVED"
}

struct Memo: Decodable, Equatable {
    let id: Int
    let createdTs: Date
    let creatorId: Int
    var content: String
    var pinned: Bool
    let rowStatus: MemosRowStatus
    let updatedTs: Date
    let visibility: MemosVisibility
    let resourceList: [Resource]?
}

struct Tag: Identifiable, Hashable {
    let name: String
    
    var id: String { name }
}

extension MemosVisibility {
    var title: LocalizedStringKey {
        switch self {
        case .public:
            return "memo.visibility.public"
        case .protected:
            return "memo.visibility.protected"
        case .private:
            return "memo.visibility.private"
        }
    }
    
    var iconName: String {
        switch self {
        case .public:
            return "globe"
        case .protected:
            return "house"
        case .private:
            return "lock"
        }
    }
}

extension Memo {
    func renderTime() -> String {
        if Calendar.current.dateComponents([.day], from: createdTs, to: .now).day! > 7 {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            return formatter.string(from: createdTs)
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: createdTs, relativeTo: .now)
    }
}
