import SwiftUI
import Models
import Account
import DesignSystem

public struct Attachment: View {
    public let resource: any ResourcePresentable
    private let resourceManager: (any ResourceManager)?
    @Environment(AccountManager.self) private var memosManager: AccountManager
    @Environment(\.openURL) private var openURL
    @State private var downloadedURL: URL?
    @State private var downloadError: Error?
    @State private var showingErrorToast = false
    @State private var downloading = false

    public init(resource: any ResourcePresentable, resourceManager: (any ResourceManager)? = nil) {
        self.resource = resource
        self.resourceManager = resourceManager
    }

    public var body: some View {
        let button = Button {
            Task {
                do {
                    guard let stored = resource as? StoredResource else {
                        // Non-local resources (e.g. Explore from other users) open directly in browser.
                        if let url = resource.url {
                            openURL(url)
                            return
                        }
                        throw MoeMemosError.invalidParams
                    }

                    downloading = true
                    if let localPath = stored.localPath, FileManager.default.fileExists(atPath: localPath) {
                        downloadedURL = URL(fileURLWithPath: localPath)
                    } else if let memos = memosManager.currentService {
                        downloadedURL = try await memos.ensureLocalResourceFile(id: stored.id)
                    }
                } catch {
                    showingErrorToast = true
                    downloadError = error
                }
                downloading = false
            }
        } label: {
            HStack {
                Image(systemName: "paperclip")
                Text(resource.filename)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding([.top, .bottom], 5)
        .toast(isPresenting: $showingErrorToast, alertType: .systemImage("xmark.circle", downloadError?.localizedDescription))
        .toast(isPresenting: $downloading, alertType: .loading)
        .fullScreenCover(item: $downloadedURL) { url in
            QuickLookPreview(selectedURL: url, urls: [url])
                .edgesIgnoringSafeArea(.bottom)
                .background(TransparentBackground())
        }

        if resourceManager != nil, resource is StoredResource {
            button.contextMenu {
                menu()
            }
        } else {
            button
        }
    }

    @ViewBuilder
    func menu() -> some View {
        if let resourceManager, let storedResource = resource as? StoredResource {
            Button(role: .destructive, action: {
                Task {
                    try await resourceManager.deleteResource(id: storedResource.id)
                }
            }, label: {
                Label("Delete", systemImage: "trash")
            })
        }
    }
}
