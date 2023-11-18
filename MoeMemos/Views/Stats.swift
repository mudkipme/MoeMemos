//
//  Stats.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

fileprivate let weekDaySymbols: [String] = {
    var symbols = Calendar.current.shortWeekdaySymbols
    let firstWeekday = Calendar.current.firstWeekday - 1
    return [String](symbols[firstWeekday...] + symbols[0..<firstWeekday])
}()

struct Stats: View {
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @Environment(UserState.self) private var userState: UserState
    
    var body: some View {
        VStack {
            HStack {
                VStack {
                    Text("\(memosViewModel.memoList.count)")
                        .font(.title2)
                    Text("stats.memo")
                        .textCase(.uppercase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack {
                    Text("\(memosViewModel.tags.count)")
                        .font(.title2)
                    Text("stats.tag")
                        .textCase(.uppercase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack {
                    Text("\(days())")
                        .font(.title2)
                    Text("stats.day")
                        .textCase(.uppercase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            
            HStack {
                VStack(alignment: .trailing) {
                    Text(weekDaySymbols.first ?? "")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text(weekDaySymbols[weekDaySymbols.count / 2])
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text(weekDaySymbols.last ?? "")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Heatmap(matrix: memosViewModel.matrix, alignment: .trailing)
            }
            .frame(minHeight: 120, maxHeight: 120)
            .padding(.bottom, 10)
        }
    }
    
    func days() -> Int {
        guard let user = userState.currentUser else { return 0 }
        guard let createdTs = user.createdTs else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(timeIntervalSince1970: TimeInterval(createdTs)), to: .now).day!
    }
}

struct Stats_Previews: PreviewProvider {
    static var previews: some View {
        Stats()
            .environmentObject(MemosViewModel())
            .environment(UserState())
    }
}
