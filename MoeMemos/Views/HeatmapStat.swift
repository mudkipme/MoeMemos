//
//  HeatmapStat.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/6.
//

import SwiftUI

struct HeatmapStat: View {
    let day: DailyUsageStat
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if Calendar.current.isDateInToday(day.date) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(.foreground, style: StrokeStyle(lineWidth: 1))
                .background(RoundedRectangle(cornerRadius: 2).fill(color(of: day)))
                .aspectRatio(1, contentMode: .fit)
                
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(of: day))
                .aspectRatio(1, contentMode: .fit)
        }
    }
    
    func color(of day: DailyUsageStat) -> Color {
        switch day.count {
        case 0:
            return colorScheme == .dark
                ? Color(uiColor: .secondarySystemBackground)
                : Color(0xeaeaea)
        case 1:
            return Color(0x9be9a8)
        case 2:
            return Color(0x40c463)
        case 3...4:
            return Color(0x30a14e)
        default:
            return Color(0x216e39)
        }
    }
}

struct HeatmapStat_Previews: PreviewProvider {
    static var previews: some View {
        HeatmapStat(day: DailyUsageStat(date: .now, count: 1))
    }
}
