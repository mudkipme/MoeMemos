//
//  Memo.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import Foundation
import SwiftUI
import MemosService

extension MemosVisibility {
    var title: LocalizedStringKey {
        switch self {
        case .PUBLIC:
            return "memo.visibility.public"
        case .PROTECTED:
            return "memo.visibility.protected"
        case .PRIVATE:
            return "memo.visibility.private"
        }
    }
    
    var iconName: String {
        switch self {
        case .PUBLIC:
            return "globe"
        case .PROTECTED:
            return "house"
        case .PRIVATE:
            return "lock"
        }
    }
}

extension MemosMemo {
    func renderTime() -> String {
        if Calendar.current.dateComponents([.day], from: createDate, to: .now).day! > 7 {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            return formatter.string(from: createDate)
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: createDate, relativeTo: .now)
    }
}
