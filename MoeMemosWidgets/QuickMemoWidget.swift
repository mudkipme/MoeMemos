//
//  QuickMemoWidget.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/20.
//

import WidgetKit
import SwiftUI

@available(iOS 18.0, *)
struct QuickMemoWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "me.mudkip.MoeMemos.QuickMemoWidget") {
            ControlWidgetButton(action: AppOpenIntent()) {
                Label("Quick Memo", systemImage: "note.text.badge.plus")
            }
        }
        .displayName("Quick Memo")
        .description("Write a memo in Moe Memos.")
    }
}
