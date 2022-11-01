//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("memosHost") private var memosHost = ""
    @EnvironmentObject private var userState: UserState
    @State private var selection: Route? = .memos
    @StateObject private var memosViewModel = MemosViewModel()
    
    @ViewBuilder
    private func navigation() -> some View {
        if #available(iOS 16, *) {
            Navigation(selection: $selection)
        } else {
            NavigationView {
                Sidebar(selection: $selection)
            }
        }
    }
    
    var body: some View {
        navigation()
            .tint(.green)
            .task {
                await loadCurrentUser()
            }
            .sheet(isPresented: $userState.showingLogin) {
                Login()
            }
            .environmentObject(memosViewModel)
    }
    
    func loadCurrentUser() async {
        do {
            try userState.reset(memosHost: memosHost)
            try await userState.loadCurrentUser()
        } catch MemosError.notLogin {
            userState.showingLogin = true
            return
        } catch MemosError.invalidStatusCode(let statusCode, let message) {
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
            .environmentObject(UserState())
    }
}
