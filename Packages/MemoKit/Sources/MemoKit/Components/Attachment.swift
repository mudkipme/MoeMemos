import SwiftUI
import Models
import Account
import DesignSystem

public struct Attachment: View {
    public let resource: any ResourcePresentable
    @Environment(AccountManager.self) private var memosManager: AccountManager
    @State private var downloadedURL: URL?
    @State private var downloadError: Error?
    @State private var showingErrorToast = false
    @State private var downloading = false

    public init(resource: any ResourcePresentable) {
        self.resource = resource
    }

    public var body: some View {
        Button {
            Task {
                do {
                    downloading = true
                    guard let url = resource.url else { throw MoeMemosError.invalidParams }
                    if let memos = memosManager.currentService {
                        downloadedURL = try await memos.download(url: url, mimeType: resource.mimeType)
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
    }
}
