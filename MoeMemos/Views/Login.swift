//
//  Login.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import KeychainSwift
import Models

struct Login: View {
    private enum LoginMethod: Hashable {
        case usernamdAndPassword
        case accessToken
    }
    
    @AppStorage(memosHostKey, store: UserDefaults(suiteName: AppInfo.groupContainerIdentifier)) var memosHost = ""
    @State private var keychain = {
        let keychain = KeychainSwift()
        keychain.accessGroup = AppInfo.keychainAccessGroupName
        return keychain
    }()

    @State private var host = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accessToken = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var userState: UserState
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var loginError: Error?
    @State private var showingErrorToast = false
    @State private var showLoadingToast = false
    @State private var loginMethod: LoginMethod = .usernamdAndPassword
    
    var body: some View {
        VStack {
            Text("moe-memos")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding(.bottom, 10)
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
        .onAppear {
            if host == "" {
                host = memosHost
            }
        }
        .toast(isPresenting: $showingErrorToast, alertType: .systemImage("xmark.circle", loginError?.localizedDescription))
        .toast(isPresenting: $showLoadingToast, alertType: .loading)
        .interactiveDismissDisabled()
    }
    
    func doLogin() async throws {
        if host.isEmpty {
            throw MemosError.invalidParams
        }
        
        var hostAddress = host.trimmingCharacters(in: .whitespaces)
        if !hostAddress.contains("//") {
            hostAddress = "https://" + hostAddress
        }
        
        if loginMethod == .usernamdAndPassword {
            if email.trimmingCharacters(in: .whitespaces).isEmpty ||
                password.isEmpty {
                throw MemosError.invalidParams
            }
            try await userState.signIn(
                memosHost: hostAddress,
                input: MemosSignIn.Input(
                    email: email.trimmingCharacters(in: .whitespaces),
                    username: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    remember: true))
            memosHost = hostAddress
            keychain.delete(memosAccessTokenKey)
        } else if loginMethod == .accessToken {
            if accessToken.trimmingCharacters(in: .whitespaces).isEmpty {
                throw MemosError.invalidParams
            }
            
            try await userState.signIn(memosHost: hostAddress, accessToken: accessToken.trimmingCharacters(in: .whitespaces))
            memosHost = try userState.memos.host.absoluteString
            keychain.set(accessToken.trimmingCharacters(in: .whitespaces), forKey: memosAccessTokenKey)
        }
        
        try await memosViewModel.loadMemos()
        dismiss()
    }
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        Login()
            .environmentObject(MemosViewModel())
            .environmentObject(UserState())
    }
}
