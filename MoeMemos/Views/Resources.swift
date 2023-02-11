//
//  Resources.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/10.
//

import SwiftUI

fileprivate let columns = [GridItem(.adaptive(minimum: 125, maximum: 200), spacing: 10), GridItem(.adaptive(minimum: 125, maximum: 200), spacing: 10)]


struct Resources: View {
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @StateObject private var viewModel = ResourceListViewModel()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(viewModel.resourceList) { resource in
                    ResourceCard(resource: resource, resourceManager: viewModel)
                }
            }
            .padding()
        }
        .navigationTitle("resources")
        .task {
            do {
                try await viewModel.loadResources()
            } catch {
                print(error)
            }
        }
    }
}

struct Resources_Previews: PreviewProvider {
    static var previews: some View {
        Resources()
            .environmentObject(MemosViewModel())
    }
}
