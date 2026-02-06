import SwiftUI
import Models
import Account
import DesignSystem

@MainActor
public struct ResourceCard: View {
    private let resource: StoredResource
    private let resourceManager: ResourceManager

    public init(resource: StoredResource, resourceManager: ResourceManager) {
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
                menu()
            }
            .task {
                do {
                    if downloadedURL != nil {
                        return
                    }
                    if let localPath = resource.localPath, FileManager.default.fileExists(atPath: localPath) {
                        downloadedURL = URL(fileURLWithPath: localPath)
                        return
                    }
                    if let memos = memosManager.currentService {
                        downloadedURL = try await memos.ensureLocalResourceFile(id: resource.id)
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
    func menu() -> some View {
        Button(role: .destructive, action: {
            Task {
                try await resourceManager.deleteResource(id: resource.id)
            }
        }, label: {
            Label("Delete", systemImage: "trash")
        })
    }
}
