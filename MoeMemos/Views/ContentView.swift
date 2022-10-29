//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI

struct ContentView: View {
    @State private var showingLogin = false
    @AppStorage("memosHost") private var memosHost = ""
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var selection: Route? = .memos
    
    @ViewBuilder
    private func navigation() -> some View {
        if #available(iOS 16, *) {
            Navigation(showingLogin: $showingLogin, selection: $selection)
        } else {
            NavigationView {
                Sidebar(showingLogin: $showingLogin, selection: $selection)
            }
        }
    }
    
    var body: some View {
        navigation()
            .tint(.green)
            .task {
                await loadCurrentUser()
            }
            .sheet(isPresented: $showingLogin) {
                Login()
            }
    }
    
    func loadCurrentUser() async {
        do {
            try memosViewModel.reset(memosHost: memosHost)
            try await memosViewModel.loadCurrentUser()
        } catch MemosError.notLogin {
            showingLogin = true
            return
        } catch MemosError.invalidStatusCode(let statusCode, let message) {
            if statusCode == 401 {
                showingLogin = true
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
            .environmentObject(MemosViewModel())
    }
}
