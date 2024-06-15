//
//  Settings.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI
import Models
import Account

@MainActor
struct Settings: View {
    @Environment(AppInfo.self) var appInfo: AppInfo
    @Environment(AccountViewModel.self) var accountViewModel

    var body: some View {
        @Bindable var accountViewModel = accountViewModel
        List {
            AccountSectionView()
            
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
        }
        .navigationTitle("settings")
    }
}
