//
//  Login.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI

struct Login: View {
    @State var host: String = ""
    @State var email: String = ""
    @State var password: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Moe Memos")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding(.bottom, 10)
            Text("Please input your login information of your Memos instance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)

            TextField("Host", text: $host)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button {
                dismiss()
            } label: {
                Text("Sign in")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
        .padding()
        
    }
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        Login()
    }
}
