//
//  MoeMemosWidgetsBundle.swift
//  MoeMemosWidgets
//
//  Created by Mudkip on 2022/11/11.
//

import WidgetKit
import SwiftUI

@main
struct MoeMemosWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MemosGraphWidget()
        MemoryWidget()
        if #available(iOS 18.0, *) {
            QuickMemoWidget()
        }
    }
}
