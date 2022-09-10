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
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(memosViewModel.resourceList) { resource in
                    gridContent(for: resource)
                }
            }
            .padding()
        }
        .navigationTitle("Resources")
        .task {
            do {
                try await memosViewModel.loadResources()
            } catch {
                print(error)
            }
        }
    }
    
    @ViewBuilder
    func gridContent(for resource: Resource) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url = url(for: resource) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    func url(for resource: Resource) -> URL? {
        memosViewModel.hostURL?
            .appendingPathComponent("/o/r")
            .appendingPathComponent("\(resource.id)")
            .appendingPathComponent(resource.filename)
    }
}

struct Resources_Previews: PreviewProvider {
    static var previews: some View {
        Resources()
            .environmentObject(MemosViewModel())
    }
}
