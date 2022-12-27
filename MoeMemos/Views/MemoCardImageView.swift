//
//  MemoCardImageView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/12/26.
//

import SwiftUI
import QuickLook

struct MemoCardImageView: View {
    let images: [URL]
    
    @State private var imagePreviewURL: URL?
    @State private var loadError: Error?
    @EnvironmentObject private var memosManager: MemosManager
    @State private var downloads = [URL: URL]()
    
    @ViewBuilder
    func asyncImage(url: URL) -> some View {
        if let downloaded = downloads[url] {
            AsyncImage(url: downloaded) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .onTapGesture {
                        Task {
                            imagePreviewURL = downloaded
                        }
                    }
            } placeholder: {
                ProgressView()
            }
        } else {
            ProgressView()
                .task {
                    do {
                        if downloads[url] == nil, let memos = memosManager.memos {
                            downloads[url] = try await memos.download(url: url)
                        }
                    } catch {}
                }
        }
    }
    
    var body: some View {
        VStack {
            ForEach(images) { url in
                asyncImage(url: url)
                .frame(width: 160, height: 160)
                .cornerRadius(8)
                .padding([.bottom], 10)
                .clipped()
            }
        }
        .quickLookPreview($imagePreviewURL, in: images.compactMap { downloads[$0] })
    }
}

struct MemoCardImageView_Previews: PreviewProvider {
    static var previews: some View {
        MemoCardImageView(images: [])
    }
}
