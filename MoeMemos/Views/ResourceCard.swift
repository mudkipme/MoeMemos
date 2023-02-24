//
//  ResourceCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/11.
//

import SwiftUI

struct ResourceCard: View {
    let resource: Resource
    let resourceManager: ResourceManager
    
    init(resource: Resource, resourceManager: ResourceManager) {
        self.resource = resource
        self.resourceManager = resourceManager
    }
    
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @EnvironmentObject private var memosManager: MemosManager
    @State private var imagePreviewURL: URL?
    @State private var downloadedURL: URL?
    
    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let downloadedURL = downloadedURL {
                    AsyncImage(url: downloadedURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .onTapGesture {
                        imagePreviewURL = downloadedURL
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contextMenu {
                menu(for: resource)
            }
            .task {
                do {
                    if downloadedURL == nil, let memos = memosManager.memos {
                        downloadedURL = try await memos.download(url: memos.url(for: resource))
                    }
                } catch {}
            }
            .fullScreenCover(item: $imagePreviewURL) { url in
                QuickLookPreview(selectedURL: url, urls: [url])
                    .edgesIgnoringSafeArea(.bottom)
                    .background(TransparentBackground())
            }
    }
    
    @ViewBuilder
    func menu(for resource: Resource) -> some View {
        Button(role: .destructive, action: {
            Task {
                try await resourceManager.deleteResource(id: resource.id)
            }
        }, label: {
            Label("Delete", systemImage: "trash")
        })
    }
}

struct ResourceCard_Previews: PreviewProvider {
    static var previews: some View {
        ResourceCard(resource: Resource(id: 1, createdTs: .now, creatorId: 0, filename: "", size: 0, type: "image/jpeg", updatedTs: .now, externalLink: nil), resourceManager: ResourceListViewModel())
            .environmentObject(MemosViewModel())
            .environmentObject(MemosManager())
    }
}
