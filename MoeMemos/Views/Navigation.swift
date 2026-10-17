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
    @Environment(AppPath.self) private var appPath
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .detail
    @State private var currentRoute: Route = .memos
    @State private var navigationPath: [Route] = []
    @State private var pathUpdateTask: Task<Void, Never>?

    var body: some View {
        @Bindable var appPath = appPath

        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredCompactColumn) {
            Sidebar(selection: $selection)
        } detail: {
            NavigationStack(path: $navigationPath) {
                currentRoute.destination()
                .navigationDestination(for: Route.self) { route in
                    route.destination()
                }
            }
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue else {
                return
            }
            currentRoute = newValue
            navigationPath.removeAll()
            preferredCompactColumn = .detail
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
        preferredCompactColumn = .detail
        defer {
            appPath.navigationRequest = nil
        }

        switch request {
        case .replace(let root, let path):
            selection = root
            currentRoute = root
            schedulePathUpdate(path)
        case .push(let route):
            if currentDestinationRoute == route {
                return
            }
            var requestedPath = navigationPath
            requestedPath.append(route)
            schedulePathUpdate(requestedPath)
        }
    }

    private var currentDestinationRoute: Route {
        navigationPath.last ?? currentRoute
    }

    private func schedulePathUpdate(_ path: [Route]) {
        pathUpdateTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            navigationPath = path
        }
    }
}
