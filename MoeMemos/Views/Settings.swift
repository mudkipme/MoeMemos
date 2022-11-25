//
//  Settings.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI

struct Settings: View {
    @EnvironmentObject var userState: UserState

    var body: some View {
        List {
            if let user = userState.currentUser {
                VStack(alignment: .leading) {
                    Text(user.displayName)
                        .font(.title3)
                    if user.displayName != user.email {
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding([.top, .bottom], 10)
            } else {
                Button {
                    userState.showingLogin = true
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
            
            if userState.currentUser != nil {
                Button(role: .destructive) {
                    Task {
                        try await userState.logout()
                        userState.showingLogin = true
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
    static var previews: some View {
        Settings()
            .environmentObject(UserState())
    }
}
