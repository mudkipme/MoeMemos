//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI
import KeychainSwift

struct ContentView: View {
    @AppStorage(memosHostKey, store: UserDefaults(suiteName: groupContainerIdentifier)) private var memosHost = ""
    @AppStorage(memosOpenIdKey, store: UserDefaults(suiteName: groupContainerIdentifier)) private var memosOpenId: String?
    @State private var keychain = {
        let keychain = KeychainSwift()
        keychain.accessGroup = keychainAccessGroupName
        return keychain
    }()

    @EnvironmentObject private var userState: UserState
    @State private var selection: Route? = .memos
    @StateObject private var memosViewModel = MemosViewModel()
    @Environment(\.scenePhase) var scenePhase

    
    @ViewBuilder
    private func navigation() -> some View {
        Navigation(selection: $selection)
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
            .onChange(of: scenePhase) { newValue in
                if newValue == .active && userState.currentUser != nil {
                    Task {
                        do {
                            try await userState.loadCurrentUser()
                        } catch MemosError.invalidStatusCode(let statusCode, _) {
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
            if let legacyMemosHost = UserDefaults.standard.string(forKey: memosHostKey), !legacyMemosHost.isEmpty {
                memosHost = legacyMemosHost
                UserDefaults.standard.removeObject(forKey: memosHostKey)
            }
            
            let accessToken = keychain.get(memosAccessTokenKey)
            try await userState.reset(memosHost: memosHost, accessToken: accessToken, openId: memosOpenId)
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
