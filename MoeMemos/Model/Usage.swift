//
//  Usage.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import Foundation

struct DailyUsageStat: Identifiable {
    let date: Date
    let count: Int
    
    var id: String {
        date.formatted(date: .numeric, time: .omitted)
    }
    
    static let initialMatrix: [DailyUsageStat] = {
        return Calendar.current.range(of: .day, in: .year, for: Date())!.map { day in
            Self.init(date: Calendar.current.date(byAdding: .day, value: -day, to: .now)!, count: 0)
        }.reversed()
    }()
}
