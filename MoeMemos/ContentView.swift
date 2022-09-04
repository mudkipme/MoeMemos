//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI

struct ContentView: View {
    @State private var showingLogin = false
    
    var body: some View {
        NavigationView {
            Sidebar()
                .toolbar {
                    Button {
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .navigationTitle("Mudkip")
        }
        .tint(.green)
        .onAppear {
            showingLogin = true
        }
        .sheet(isPresented: $showingLogin) {
            Login()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
