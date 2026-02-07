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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var currentRoute: Route = .memos

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $selection)
        } detail: {
            NavigationStack {
                currentRoute.destination()
                .navigationDestination(for: Route.self) { route in
                    route.destination()
                }
            }
        }
        .onChange(of: horizontalSizeClass, initial: true) { _, newValue in
            if newValue == .compact {
                columnVisibility = .detailOnly
            } else {
                columnVisibility = .all
            }
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue else {
                return
            }
            currentRoute = newValue
            if horizontalSizeClass == .compact {
                columnVisibility = .detailOnly
            }
        }
        .onAppear {
            if let selection {
                currentRoute = selection
            } else {
                selection = currentRoute
            }
        }
    }
}
