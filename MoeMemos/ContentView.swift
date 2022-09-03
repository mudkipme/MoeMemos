//
//  ContentView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/3.
//

import SwiftUI

struct ContentView: View {
    @State private var toMemosList = true
    
    var body: some View {
        NavigationView {
            ZStack {
                NavigationLink(destination: MemosList(), isActive: $toMemosList) {
                    Text("Hello, world!")
                        .padding()
                }
            }.navigationTitle("Mudkip")
        }
        .tint(.green)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
