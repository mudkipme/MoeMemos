//
//  ShareSheet.swift
//  ShareSheetDemo
//
//  Created by Jim Dovey on 10/7/19.
//  Copyright © 2019 Jim Dovey. All rights reserved.
//
import SwiftUI
import UIKit

@available(iOS, deprecated: 16.0, message: "Use ShareLink")
struct LegacyShareSheet: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void
    
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil
    let callback: Callback? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // nothing to do here
    }
}

struct LegacyShareSheet_Previews: PreviewProvider {
    static var previews: some View {
        LegacyShareSheet(activityItems: ["A string" as NSString])
    }
}
