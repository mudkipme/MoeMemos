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
    @State private var host = ""
    @State private var accessToken = ""
    let dismiss: DismissAction
    @Environment(AccountViewModel.self) private var accountViewModel
    @State private var loginError: Error?
    @State private var showingErrorToast = false
    @State private var showLoadingToast = false
    
    var body: some View {
        VStack {
            Text("login.hint")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            
            TextField("login.host", text: $host)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
            
            SecureField("login.access-token", text: $accessToken)
                .textFieldStyle(.roundedBorder)
            Text("login.access-token.hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
            
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
        .navigationTitle("account.add-memos-account")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func doLogin() async throws {
        if host.isEmpty {
            throw MoeMemosError.invalidParams
        }
        
        var hostAddress = host.trimmingCharacters(in: .whitespaces)
        if !hostAddress.contains("//") {
            hostAddress = "https://" + hostAddress
        }
        if hostAddress.last == "/" {
            hostAddress.removeLast()
        }
        
        guard let hostURL = URL(string: hostAddress) else { throw MoeMemosError.invalidParams }
        let server = try await detectMemosVersion(hostURL: hostURL)

        let accessToken = accessToken.trimmingCharacters(in: .whitespaces)
        if accessToken.isEmpty {
            throw MoeMemosError.invalidParams
        }
        
        switch server {
        case .v1(version: _):
            try await accountViewModel.loginMemosV1(hostURL: hostURL, accessToken: accessToken)
        case .v0(version: _):
            try await accountViewModel.loginMemosV0(hostURL: hostURL, accessToken: accessToken)
        }
        dismiss()
    }
}
