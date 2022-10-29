//
//  Navigation.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/10/30.
//

import SwiftUI

@available(iOS 16, *)
struct Navigation: View {
    @Binding var showingLogin: Bool
    @Binding var selection: Route?
    @State private var path: NavigationPath = NavigationPath([Route.memos])
    
    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .memos:
            MemosList(tag: nil)
        case .resources:
            Resources()
        case .archived:
            ArchivedMemosList()
        case .tag(let tag):
            MemosList(tag: tag)
        case .settings:
            Settings(showingLogin: $showingLogin)
        }
    }
    
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(sidebar: {
                Sidebar(showingLogin: $showingLogin, selection: $selection)
            }) {
                if let selection = selection {
                    destination(selection)
                }
            }
            
        } else {
            NavigationStack(path: $path) {
                Sidebar(showingLogin: $showingLogin, selection: $selection)
                    .navigationDestination(for: Route.self, destination: destination(_:))
            }
        }
    }
}

@available(iOS 16, *)
struct Navigation_Previews: PreviewProvider {
    @State static var showingLogin = true
    @State static var selection: Route? = nil

    static var previews: some View {
        Navigation(showingLogin: $showingLogin, selection: $selection)
    }
}
