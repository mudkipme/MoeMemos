//
//  NavLink.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import SwiftUI

struct NavLink<Label> : View where Label : View {
    let route: Route
    let label: () -> Label
    
    var body: some View {
        if #available(iOS 16, *) {
            NavigationLink(value: route, label: label)
        } else {
            NavigationLink(destination: route.destination(), label: label)
        }
    }
}
