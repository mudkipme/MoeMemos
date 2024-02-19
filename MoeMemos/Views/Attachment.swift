//
//  Attachment.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/14.
//

import SwiftUI
import MemosService
import Account

struct Attachment: View {
    let resource: MemosResource
    @State var showingAttachment = false
    @Environment(AccountManager.self) private var memosManager: AccountManager
    @State private var downloadedURL: URL?
    @State private var downloadError: Error?
    @State private var showingErrorToast = false
    @State private var downloading = false
    
    var body: some View {
        Button {
            Task {
                do {
                    downloading = true
                    if let memos = memosManager.currentService {
                        downloadedURL = try await memos.download(url: memos.url(for: resource))
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

struct Attachment_Previews: PreviewProvider {
    static var previews: some View {
        Attachment(resource: MemosResource(filename: "test.yml", id: 1, name: ""))
            .environment(AccountManager.shared)
    }
}
