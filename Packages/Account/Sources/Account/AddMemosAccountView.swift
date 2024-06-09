//
//  AddMemosAccountView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import Models
import MemosV0Service
import DesignSystem

@MainActor
struct AddMemosAccountView: View {
    private enum LoginMethod: Hashable {
        case usernamdAndPassword
        case accessToken
    }
    
    @State private var host = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accessToken = ""
    let dismiss: DismissAction
    @Environment(AccountManager.self) var accountManager: AccountManager
    @State private var loginError: Error?
    @State private var showingErrorToast = false
    @State private var showLoadingToast = false
    @State private var loginMethod: LoginMethod = .usernamdAndPassword
    
    var body: some View {
        VStack {
            Text("login.hint")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            
            Picker("login.method", selection: $loginMethod) {
                Text("login.username-and-password").tag(LoginMethod.usernamdAndPassword)
                Text("login.access-token").tag(LoginMethod.accessToken)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 10)
            
            TextField("login.host", text: $host)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
            
            if loginMethod == .usernamdAndPassword {
                TextField("login.username", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                SecureField("login.password", text: $password)
                    .textFieldStyle(.roundedBorder)
            } else if loginMethod == .accessToken {
                SecureField("login.access-token", text: $accessToken)
                    .textFieldStyle(.roundedBorder)
                Text("login.access-token.hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                Task {
                    do {
                        showLoadingToast = true
                        try await doLogin()
                        loginError = nil
                    } catch {
                        loginError = error
                        showingErrorToast = true
                    }
                    showLoadingToast = false
                }
            } label: {
                Text("login.sign-in")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 20)
        }
        .padding()
        .toast(isPresenting: $showingErrorToast, alertType: .systemImage("xmark.circle", loginError?.localizedDescription))
        .toast(isPresenting: $showLoadingToast, alertType: .loading)
        .navigationTitle("Memos Account")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func doLogin() async throws {
        if host.isEmpty {
            throw MoeMemosError.invalidParams
        }
        
        var hostAddress = host.trimmingCharacters(in: .whitespaces)
        if !hostAddress.contains("//") {
            hostAddress = "https://" + hostAddress
        }
        
        if loginMethod == .usernamdAndPassword {
            if email.trimmingCharacters(in: .whitespaces).isEmpty ||
                password.isEmpty {
                throw MoeMemosError.invalidParams
            }
            
            guard let url = URL(string: hostAddress) else { throw MoeMemosError.invalidParams }
            let client = MemosV0Service(hostURL: url, accessToken: nil)
            let (user, accessToken) = try await client.signIn(username: email.trimmingCharacters(in: .whitespaces), password: password)
            guard let accessToken = accessToken else { throw MoeMemosError.unsupportedVersion }
            try accountManager.add(account: .memos(host: hostAddress, id: "\(user.id)", accessToken: accessToken))
        } else if loginMethod == .accessToken {
            if accessToken.trimmingCharacters(in: .whitespaces).isEmpty {
                throw MoeMemosError.invalidParams
            }
            
            guard let url = URL(string: hostAddress) else { throw MoeMemosError.invalidParams }
            let client = MemosV0Service(hostURL: url, accessToken: accessToken.trimmingCharacters(in: .whitespaces))
            let response = try await client.getCurrentUser()
            try accountManager.add(account: .memos(host: hostAddress, id: "\(response.id)", accessToken: accessToken.trimmingCharacters(in: .whitespaces)))
        }
        dismiss()
    }
}
