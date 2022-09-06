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
        }
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
