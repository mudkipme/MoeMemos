//
//  Stats.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct Stats: View {
    var body: some View {
        HStack {
            VStack {
                Text("0")
                    .font(.title2)
                Text("Memo")
                    .textCase(.uppercase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack {
                Text("0")
                    .font(.title2)
                Text("Tag")
                    .textCase(.uppercase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack {
                Text("0")
                    .font(.title2)
                Text("Day")
                    .textCase(.uppercase)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct Stats_Previews: PreviewProvider {
    static var previews: some View {
        Stats()
    }
}
