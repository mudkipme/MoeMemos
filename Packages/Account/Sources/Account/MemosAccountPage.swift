//
//  MemosAccountPage.swift
//
//
//  Created by Mudkip on 2024/6/15.
//

import Foundation
import SwiftUI
import Models

public struct MemosAccountPage: View {
    let user: User
    
    public var body: some View {
        List {
            VStack(alignment: .leading) {
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
    }
}
