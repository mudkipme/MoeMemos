//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI

struct ContentView: View {
    @State private var showingLogin = false
    @StateObject private var memosViewModel = MemosViewModel()
    @AppStorage("memosHost") private var memosHost = ""
    
    var body: some View {
        NavigationView {
            Sidebar()
                .toolbar {
                    NavigationLink {
                        Settings(showingLogin: $showingLogin)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .navigationTitle(memosViewModel.currentUser?.name ?? "Memos")
            MemosList()
        }
        .tint(.green)
        .task {
            await loadCurrentUser()
        }
        .sheet(isPresented: $showingLogin) {
            Login()
        }
        .environmentObject(memosViewModel)
    }
    
    func loadCurrentUser() async {
        do {
            try memosViewModel.reset(memosHost: memosHost)
            try await memosViewModel.loadCurrentUser()
        } catch MemosError.notLogin {
            showingLogin = true
            return
        } catch {
            print(error)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
