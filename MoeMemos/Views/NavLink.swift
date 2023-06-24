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
        NavigationLink(value: route, label: label)
    }
}
