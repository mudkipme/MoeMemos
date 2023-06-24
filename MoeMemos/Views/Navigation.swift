//
//  Navigation.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/10/30.
//

import SwiftUI

@available(iOS 16, *)
struct Navigation: View {
    @Binding var selection: Route?
    @State private var path: NavigationPath = NavigationPath([Route.memos])

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .reality {
            NavigationSplitView(sidebar: {
                Sidebar(selection: $selection)
            }) {
                if let selection = selection {
                    selection.destination()
                }
            }
            
        } else {
            NavigationStack(path: $path) {
                Sidebar(selection: $selection)
                    .navigationDestination(for: Route.self) { route in
                        route.destination()
                    }
            }
        }
    }
}

@available(iOS 16, *)
struct Navigation_Previews: PreviewProvider {
    @State static var selection: Route? = nil

    static var previews: some View {
        Navigation(selection: $selection)
    }
}
