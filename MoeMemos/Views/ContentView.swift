//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import Models
import MemosService

struct ContentView: View {
    @Environment(UserState.self) private var userState: UserState
    @State private var selection: Route? = .memos
    @StateObject private var memosViewModel = MemosViewModel()
    @Environment(\.scenePhase) var scenePhase

    @ViewBuilder
    private func navigation() -> some View {
        Navigation(selection: $selection)
    }
    
    var body: some View {
        @Bindable var userState = userState
        
        navigation()
            .tint(.green)
            .task {
                await loadCurrentUser()
            }
            .sheet(isPresented: $userState.showingLogin) {
                Login()
            }
            .environmentObject(memosViewModel)
            .onChange(of: scenePhase) { newValue in
                if newValue == .active && userState.currentUser != nil {
                    Task {
                        do {
                            try await userState.loadCurrentUser()
                        } catch MemosServiceError.invalidStatusCode(let statusCode, _) {
                            if statusCode == 401 {
                                userState.showingLogin = true
                            }
                        }
                    }
                }
            }
    }
    
    func loadCurrentUser() async {
        do {
            try await userState.loadCurrentUser()
        } catch MemosServiceError.notLogin {
            userState.showingLogin = true
            return
        } catch MemosServiceError.invalidStatusCode(let statusCode, let message) {
            if statusCode == 401 {
                userState.showingLogin = true
                return
            }
            print("status: \(statusCode), message: \(message ?? "")")
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
