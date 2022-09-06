//
//  Login.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct Login: View {
    @AppStorage("memosHost") var memosHost = ""
    @State private var host = ""
    @State private var email = ""
    @State private var password = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var memosViewModel: MemosViewModel
    
    var body: some View {
        VStack {
            Text("Moe Memos")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding(.bottom, 10)
            Text("Please input the login information of your Memos instance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            
            TextField("Host", text: $host)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button {
                Task {
                    try await doLogin()
                }
            } label: {
                Text("Sign in")
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
    }
    
    func doLogin() async throws {
        if host.isEmpty ||
            email.trimmingCharacters(in: .whitespaces).isEmpty ||
            password.isEmpty {
            return
        }
        
        try await memosViewModel.signIn(memosHost: host, input: MemosSignIn.Input(email: email.trimmingCharacters(in: .whitespaces), password: password))
        memosHost = host
        try await memosViewModel.loadMemos()
        dismiss()
    }
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        Login()
            .environmentObject(MemosViewModel())
    }
}
