import SwiftUI
import Models
import Account

@MainActor
public struct ResourceCard: View {
    private let resource: Resource
    private let resourceManager: ResourceManager

    public init(resource: Resource, resourceManager: ResourceManager) {
        self.resource = resource
        self.resourceManager = resourceManager
    }

    @Environment(AccountManager.self) private var memosManager: AccountManager
    @State private var imagePreviewURL: URL?
    @State private var downloadedURL: URL?

    public var body: some View {
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
                    if downloadedURL == nil, let memos = memosManager.currentService {
                        downloadedURL = try await memos.download(url: resource.url, mimeType: resource.mimeType)
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
                guard let remoteId = resource.remoteId else { return }
                try await resourceManager.deleteResource(remoteId: remoteId)
            }
        }, label: {
            Label("Delete", systemImage: "trash")
        })
    }
}
