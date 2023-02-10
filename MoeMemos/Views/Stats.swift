//
//  Stats.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct Stats: View {
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @EnvironmentObject private var userState: UserState
    
    var body: some View {
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
    }
    
    func days() -> Int {
        guard let user = userState.currentUser else { return 0 }
        return Calendar.current.dateComponents([.day], from: user.createdTs, to: .now).day!
    }
}

struct Stats_Previews: PreviewProvider {
    static var previews: some View {
        Stats()
            .environmentObject(MemosViewModel())
            .environmentObject(UserState())
    }
}
