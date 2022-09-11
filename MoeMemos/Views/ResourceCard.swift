//
//  ResourceCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/11.
//

import SwiftUI

struct ResourceCard: View {
    let resource: Resource
    
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var imagePreviewURL: URL?
    @State private var showingDeleteConfirmation = false

    var body: some View {
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
                    .onTapGesture {
                        imagePreviewURL = url
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contextMenu {
                menu(for: resource)
            }
            .fullScreenCover(item: $imagePreviewURL) { url in
                if let url = url {
                    ImageViewer(imageURL: url)
                }
            }
            .confirmationDialog("Delete this resource?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Yes", role: .destructive) {
                    Task {
                        try await memosViewModel.deleteResource(id: resource.id)
                    }
                }
                Button("No", role: .cancel) {}
            }
    }
    
    @ViewBuilder
    func menu(for resource: Resource) -> some View {
        Button(role: .destructive, action: {
            showingDeleteConfirmation = true
        }, label: {
            Label("Delete", systemImage: "trash")
        })
    }
    
    private func url(for resource: Resource) -> URL? {
        memosViewModel.hostURL?
            .appendingPathComponent("/o/r")
            .appendingPathComponent("\(resource.id)")
            .appendingPathComponent(resource.filename)
    }
}

struct ResourceCard_Previews: PreviewProvider {
    static var previews: some View {
        ResourceCard(resource: Resource(id: 1, createdTs: .now, creatorId: 0, filename: "", size: 0, type: "image/jpeg", updatedTs: .now))
            .environmentObject(MemosViewModel())
    }
}
