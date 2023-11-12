//
//  Settings.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI

struct Settings: View {
    @EnvironmentObject var userState: UserState
    @StateObject var appInfo = AppInfo()

    var body: some View {
        List {
            if let user = userState.currentUser {
                VStack(alignment: .leading) {
                    Text(user.displayName)
                        .font(.title3)
                    if user.displayName != user.displayEmail && !user.displayEmail.isEmpty {
                        Text(user.displayEmail)
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
            
            if let status = userState.status {
                Text("✍️memos v\(status.profile.version)")
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
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        Settings()
            .environmentObject(UserState())
    }
}
