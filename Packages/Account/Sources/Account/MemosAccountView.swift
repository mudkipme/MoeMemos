//
//  MemosAccountView.swift
//
//
//  Created by Mudkip on 2024/6/15.
//

import Foundation
import SwiftUI
import Models
import Env

public struct MemosAccountView: View {
    @State var user: User? = nil
    @State var version: MemosVersion? = nil
    private let accountKey: String
    @Environment(AccountManager.self) private var accountManager
    @Environment(AccountViewModel.self) private var accountViewModel
    @Environment(AppPath.self) private var appPath
    private var account: Account? { accountManager.accounts.first { $0.key == accountKey } }
    @Environment(\.presentationMode) var presentationMode
    
    public init(accountKey: String) {
        self.accountKey = accountKey
    }
    
    public var body: some View {
        List {
            if let user = user {
                VStack(alignment: .leading) {
                    if let avatarData = user.avatarData, let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    }
                    Text(user.nickname)
                        .font(.title3)
                    if let email = user.email, email != user.nickname && !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding([.top, .bottom], 10)
            }
            
            if let version = version?.version {
                Label(title: { Text("memos v\(version)").foregroundStyle(.secondary) }) {
                    Image(.memos)
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                }
            }
            
            if accountKey != accountManager.currentAccount?.key {
                Section {
                    Button {
                        Task {
                            try await accountViewModel.switchTo(accountKey: accountKey)
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("account.switch-account")
                            Spacer()
                        }
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    Task {
                        guard let account = account else { return }
                        try await accountViewModel.logout(account: account)
                        presentationMode.wrappedValue.dismiss()
                        
                        if accountManager.currentAccount == nil {
                            appPath.presentedSheet = .addAccount
                        }
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
        .navigationTitle("account.account-detail")
        .task {
            guard let account = account else { return }
            user = try? await account.remoteService()?.getCurrentUser()
        }
        .task {
            guard let account = account else { return }
            
            var hostURL: URL?
            switch account {
            case .memosV0(host: let host, id: _, accessToken: _):
                hostURL = URL(string: host)
            case .memosV1(host: let host, id: _, accessToken: _):
                hostURL = URL(string: host)
            default:
                return
            }
            guard let hostURL = hostURL else { return }
            version = try? await detectMemosVersion(hostURL: hostURL)
        }
    }
}
