//
//  Navigation.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/10/30.
//

import SwiftUI
import Env

struct Navigation: View {
    @Binding var selection: Route?
    @State private var path: [Route] = [.memos]

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .vision {
            NavigationSplitView(sidebar: {
                Sidebar(selection: $selection)
            }) {
                NavigationStack {
                    Group {
                        if let selection = selection {
                            selection.destination()
                        } else {
                            EmptyView()
                        }
                    }.navigationDestination(for: Route.self) { route in
                        route.destination()
                    }
                }
            }
        } else {
            NavigationStack(path: $path) {
                Sidebar(selection: $selection)
                    .navigationDestination(for: Route.self) { route in
                        route.destination()
                    }
            }
            .onChange(of: selection, initial: true) { _, newValue in
                guard let route = newValue else {
                    return
                }

                if path != [route] {
                    path = [route]
                }
            }
            .onChange(of: path) { _, newValue in
                let newSelection = newValue.last
                if selection != newSelection {
                    selection = newSelection
                }
            }
        }
    }
}
