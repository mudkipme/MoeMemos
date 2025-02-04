//
//  AddBlinkoAccountView.swift
//  Account
//
//  Created by Mudkip on 2025/2/4.
//

import SwiftUI
import Models
import DesignSystem

@MainActor
struct AddBlinkoAccountView: View {
    @State private var host = ""
    @State private var accessToken = ""
    let dismiss: DismissAction
    @Environment(AccountViewModel.self) private var accountViewModel
    @State private var loginError: Error?
    @State private var showingErrorToast = false
    @State private var showLoadingToast = false

    var body: some View {
        VStack {
            Text("account.blinko.hint")
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
        .navigationTitle("account.add-blinko-account")
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
        guard let hostURL = URL(string: hostAddress) else { throw MoeMemosError.invalidParams }

        let accessToken = accessToken.trimmingCharacters(in: .whitespaces)
        if accessToken.isEmpty {
            throw MoeMemosError.invalidParams
        }
        
        try await accountViewModel.loginBlinkoV1(hostURL: hostURL, accessToken: accessToken)
        dismiss()
    }
}
