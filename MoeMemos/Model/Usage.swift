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
    
    static func calculateMatrix(memoList: [Memo]) -> [DailyUsageStat] {
        var result = DailyUsageStat.initialMatrix
        var countDict = [String: Int]()
        
        for memo in memoList {
            let key = memo.createdTs.formatted(date: .numeric, time: .omitted)
            countDict[key] = (countDict[key] ?? 0) + 1
        }
        
        for (i, day) in result.enumerated() {
            result[i].count = countDict[day.id] ?? 0
        }
        
        return result
    }
}
