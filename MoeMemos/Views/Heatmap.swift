//
//  Heatmap.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

fileprivate let gridSpacing: CGFloat = 3
fileprivate let daysInWeek = Calendar.current.weekdaySymbols.count
fileprivate let defaultRows = [GridItem](repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: gridSpacing), count: daysInWeek)
fileprivate let days = [Int](0...daysInWeek)

struct Heatmap: View {
    let rows = defaultRows
    var matrix = DailyUsageStat.initialMatrix
    
    var body: some View {
        GeometryReader { geometry in
            LazyHGrid(rows: rows, alignment: .top, spacing: gridSpacing) {
                ForEach(matrix.suffix(count(in: geometry.frame(in: .local).size))) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(0xEAEAEA))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
    
    private func count(in size: CGSize) -> Int {
        let cellHeight = (size.height + gridSpacing) / CGFloat(daysInWeek) - gridSpacing
        if cellHeight <= 0 {
            return 0
        }
        let cellWidth = cellHeight
        let columns = Int(floor(size.width / (cellWidth + gridSpacing)))
        return Int(columns) * daysInWeek
    }
}

struct HeatMap_Previews: PreviewProvider {
    static var previews: some View {
        Heatmap()
    }
}
