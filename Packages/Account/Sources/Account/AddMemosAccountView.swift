//
//  AddMemosAccountView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import Models
import DesignSystem

@MainActor
struct AddMemosAccountView: View {
    private struct LoginContext {
        let hostURL: URL
        let accessToken: String
        let server: MemosVersion
    }

    @State private var host = ""
    @State private var accessToken = ""
    let dismiss: DismissAction
    @Environment(AccountViewModel.self) private var accountViewModel
    @State private var loginError: Error?
    @State private var showingErrorToast = false
    @State private var showLoadingToast = false
    @State private var unsupportedVersionMessage: String?
    @State private var showingUnsupportedVersionAlert = false
    @State private var higherVersionLoginWarningMessage: String?
    @State private var showingHigherVersionLoginConfirmation = false
    @State private var pendingLoginContext: LoginContext?
    
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
                    await handleLoginTap()
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
        .alert(NSLocalizedString("compat.unsupported-version.title", comment: "Unsupported Memos version alert title"), isPresented: $showingUnsupportedVersionAlert) {
            Button(NSLocalizedString("common.ok", comment: "OK button label"), role: .cancel) {}
        } message: {
            Text(unsupportedVersionMessage ?? moeMemosSupportedMemosVersionsMessage)
        }
        .confirmationDialog(NSLocalizedString("compat.continue-login.title", comment: "Higher version login confirmation title"), isPresented: $showingHigherVersionLoginConfirmation, titleVisibility: .visible) {
            Button(NSLocalizedString("common.cancel", comment: "Cancel button label"), role: .cancel) {}
            Button(NSLocalizedString("compat.action.still-login", comment: "Continue login button label")) {
                Task {
                    await continueHigherVersionLogin()
                }
            }
        } message: {
            Text(higherVersionLoginWarningMessage ?? moeMemosHigherMemosVersionLoginWarning)
        }
        .navigationTitle("account.add-memos-account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleLoginTap() async {
        showLoadingToast = true
        defer {
            showLoadingToast = false
        }

        do {
            let context = try await prepareLoginContext()
            switch evaluateMemosVersionCompatibility(context.server) {
            case .supported:
                try await login(with: context)
            case .unsupported:
                unsupportedVersionMessage = moeMemosSupportedMemosVersionsMessage
                showingUnsupportedVersionAlert = true
            case .v1HigherThanSupported(version: _):
                pendingLoginContext = context
                higherVersionLoginWarningMessage = moeMemosHigherMemosVersionLoginWarning
                showingHigherVersionLoginConfirmation = true
            }
        } catch {
            loginError = error
            showingErrorToast = true
        }
    }

    private func continueHigherVersionLogin() async {
        guard let pendingLoginContext else { return }
        showLoadingToast = true
        defer {
            showLoadingToast = false
        }

        do {
            try await login(with: pendingLoginContext)
            self.pendingLoginContext = nil
        } catch {
            loginError = error
            showingErrorToast = true
        }
    }

    private func prepareLoginContext() async throws -> LoginContext {
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
        let trimmedAccessToken = accessToken.trimmingCharacters(in: .whitespaces)
        if trimmedAccessToken.isEmpty {
            throw MoeMemosError.invalidParams
        }

        let server = try await detectMemosVersion(hostURL: hostURL)
        return LoginContext(hostURL: hostURL, accessToken: trimmedAccessToken, server: server)
    }

    private func login(with context: LoginContext) async throws {
        switch context.server {
        case .v1(version: _):
            try await accountViewModel.loginMemosV1(hostURL: context.hostURL, accessToken: context.accessToken)
        case .v0(version: _):
            try await accountViewModel.loginMemosV0(hostURL: context.hostURL, accessToken: context.accessToken)
        }
        dismiss()
    }
}
