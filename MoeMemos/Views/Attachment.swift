//
//  Attachment.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/14.
//

import SwiftUI

struct Attachment: View {
    let resource: Resource
    @State var showingAttachment = false
    @EnvironmentObject private var memosManager: MemosManager
    @State private var downloadedURL: URL?
    @State private var downloadError: Error?
    @State private var showingErrorToast = false
    @State private var downloading = false
    
    var body: some View {
        Button {
            Task {
                do {
                    downloading = true
                    if let memos = memosManager.memos {
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
        Attachment(resource: Resource(id: 0, createdTs: Date(), creatorId: 0, filename: "test.yml", size: 0, type: "application/x-yaml", updatedTs: Date(), externalLink: nil))
            .environmentObject(MemosManager())
    }
}
