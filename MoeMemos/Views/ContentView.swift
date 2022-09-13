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
    
    @ViewBuilder
    private func sidebar() -> some View {
        Sidebar()
            .toolbar {
                NavigationLink {
                    Settings(showingLogin: $showingLogin)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .navigationTitle(memosViewModel.currentUser?.name ?? "Memos")
    }
    
    @ViewBuilder
    private func navigation() -> some View {
        if #available(iOS 16, *), UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(sidebar: {
                sidebar()
            }) {
                MemosList(tag: nil)
            }
        } else {
            NavigationView {
                sidebar()
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
