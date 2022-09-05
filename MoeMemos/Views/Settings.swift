//
//  Settings.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI

struct Settings: View {
    @EnvironmentObject var memosViewModel: MemosViewModel
    @Binding var showingLogin: Bool

    var body: some View {
        List {
            if let user = memosViewModel.currentUser {
                VStack(alignment: .leading) {
                    Text(user.name)
                        .font(.title3)
                    if user.name != user.email {
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding([.top, .bottom], 10)
            } else {
                Button {
                    showingLogin = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign in")
                        Spacer()
                    }
                }
            }
            
            Section {
                Link(destination: URL(string: "https://memos.moe")!) {
                    Label("Website", systemImage: "globe")
                }
                Link(destination: URL(string: "https://memos.moe/privacy")!) {
                    Label("Privacy Policy", systemImage: "lock")
                }
            } header: {
                Text("About Moe Memos")
            }
            
            if memosViewModel.currentUser != nil {
                Button(role: .destructive) {
                    Task {
                        try await memosViewModel.logout()
                        showingLogin = true
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign out")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct Settings_Previews: PreviewProvider {
    @State static var showingLogin = true

    static var previews: some View {
        Settings(showingLogin: $showingLogin)
    }
}
