//
//  Settings.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI
import Models

struct Settings: View {
    @Environment(UserState.self) var userState: UserState
    @State var appInfo = AppInfo()

    var body: some View {
        List {
            if let user = userState.currentUser {
                VStack(alignment: .leading) {
                    if let nickname = user.nickname {
                        Text(nickname)
                            .font(.title3)
                    }
                    if let email = user.email {
                        Text(email)
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
                        Text("login.sign-in")
                        Spacer()
                    }
                }
            }
            
            if let version = userState.currentStatus?.profile?.version {
                Text("✍️memos v\(version)")
                    .foregroundStyle(.secondary)
            }
            
            
            Section {
                Link(destination: appInfo.website) {
                    Label("settings.website", systemImage: "globe")
                }
                Link(destination: appInfo.privacy) {
                    Label("settings.privacy", systemImage: "lock")
                }
                Link(destination: URL(string: "https://memos.moe/ios-acknowledgements")!) {
                    Label("settings.acknowledgements", systemImage: "info.bubble")
                }
                Link(destination: URL(string: "https://github.com/mudkipme/MoeMemos/issues")!) {
                    Label("settings.report", systemImage: "smallcircle.filled.circle")
                }
            } header: {
                Text("settings.about")
            } footer: {
                Text(appInfo.registration)
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
                        Text("settings.sign-out")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("settings")
        .task {
            do {
                try await userState.loadCurrentStatus()
            } catch {}
        }
    }
}
