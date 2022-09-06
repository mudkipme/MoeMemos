//
//  Usage.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import Foundation


struct DailyUsageStat: Identifiable {
    let date: Date
    var count: Int
    
    var id: String {
        date.formatted(date: .numeric, time: .omitted)
    }
    
    static let initialMatrix: [DailyUsageStat] = {
        let today = Calendar.current.startOfDay(for: .now)
        
        return Calendar.current.range(of: .day, in: .year, for: Date())!.map { day in
            return Self.init(date: Calendar.current.date(byAdding: .day, value: 1 - day, to: today)!, count: 0)
        }.reversed()
    }()
}
