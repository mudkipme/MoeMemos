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
    @Environment(AppPath.self) private var appPath
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var currentRoute: Route = .memos
    @State private var navigationPath: [Route] = []
    @State private var pathUpdateTask: Task<Void, Never>?

    var body: some View {
        @Bindable var appPath = appPath

        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(selection: $selection)
        } detail: {
            NavigationStack(path: $navigationPath) {
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
            navigationPath.removeAll()
            if horizontalSizeClass == .compact {
                columnVisibility = .detailOnly
            }
        }
        .onChange(of: appPath.navigationRequest) { _, newValue in
            guard let newValue else {
                return
            }
            applyNavigationRequest(newValue, appPath: appPath)
        }
        .onAppear {
            if let selection {
                currentRoute = selection
            } else {
                selection = currentRoute
            }
            if let request = appPath.navigationRequest {
                applyNavigationRequest(request, appPath: appPath)
            }
        }
        .onDisappear {
            pathUpdateTask?.cancel()
        }
    }

    private func applyNavigationRequest(_ request: NavigationRequest, appPath: AppPath) {
        pathUpdateTask?.cancel()
        selection = request.root
        currentRoute = request.root
        appPath.navigationRequest = nil

        let requestedPath = request.path
        pathUpdateTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            navigationPath = requestedPath
        }
    }
}
