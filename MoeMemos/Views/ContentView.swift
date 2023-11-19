//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import Models
import MemosService
import SwiftData

struct ContentView: View {
    @State private var container = try? ModelContainer(
        for: Memo.self, Resource.self, Tag.self, User.self,
        configurations: .init(groupContainer: .identifier(AppInfo.groupContainerIdentifier))
    )
    @Environment(UserState.self) private var userState: UserState
    @State private var selection: Route? = .memos
    @StateObject private var memosViewModel = MemosViewModel()
    @Environment(\.scenePhase) var scenePhase

    @ViewBuilder
    private func content() -> some View {
        @Bindable var userState = userState

        Navigation(selection: $selection)
            .tint(.green)
            .sheet(isPresented: $userState.showingLogin) {
                Login()
            }
            .environmentObject(memosViewModel)
            .onChange(of: scenePhase, initial: true, { _, newValue in
                if newValue == .active && userState.currentUser != nil {
                    Task {
                        await loadCurrentUser()
                    }
                }
            })
    }
    
    var body: some View {
        if let container = container {
            content()
                .modelContainer(container)
        } else {
            content()
        }
    }
    
    @MainActor
    func loadCurrentUser() async {
        do {
            try await userState.loadCurrentUser()
        } catch {
            print(error)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(UserState())
    }
}
