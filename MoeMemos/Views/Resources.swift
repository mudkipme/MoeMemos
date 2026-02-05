//
//  Resources.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/10.
//

import SwiftUI
import MemoKit

fileprivate let columns = [GridItem(.adaptive(minimum: 125, maximum: 200), spacing: 10), GridItem(.adaptive(minimum: 125, maximum: 200), spacing: 10)]


struct Resources: View {
    @Environment(MemosViewModel.self) private var memosViewModel: MemosViewModel
    @State private var viewModel = ResourceListViewModel()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(viewModel.resourceList) { item in
                    ResourceCard(resource: item, resourceManager: viewModel)
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
