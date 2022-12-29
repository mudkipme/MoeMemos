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
    @EnvironmentObject private var memosManager: MemosManager
    @State private var downloads = [URL: URL]()
    
    @ViewBuilder
    private func asyncImage(url: URL) -> some View {
        if let downloaded = downloads[url] {
            AsyncImage(url: downloaded) { image in
                image
                    .resizable()
                    .scaledToFill()
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
    
    @ViewBuilder
    private func imageItem(url: URL, aspectRatio: CGFloat, contentMode: ContentMode) -> some View {
        Color.clear.overlay {
            asyncImage(url: url)
        }
        .aspectRatio(aspectRatio, contentMode: contentMode)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .cornerRadius(8)
        .clipped()
    }
    
    @ViewBuilder
    private var content: some View {
        switch images.count {
        case 1:
            imageItem(url: images[0], aspectRatio: 16.0 / 9.0, contentMode: .fit)
        case 2...3:
            HStack(spacing: 5) {
                ForEach(images) { url in
                    imageItem(url: url, aspectRatio: 1.0, contentMode: .fill)
                }
            }
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
        default:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: images.count == 4 ? 120 : 90, maximum: 150), spacing: 5)], spacing: 5) {
                ForEach(images) { url in
                    imageItem(url: url, aspectRatio: 1.0, contentMode: .fill)
                }
            }
        }
    }
    
    var body: some View {
        content
            .padding([.bottom], 10)
            .quickLookPreview($imagePreviewURL, in: images.compactMap { downloads[$0] })
    }
}

struct MemoCardImageView_Previews: PreviewProvider {
    static var previews: some View {
        MemoCardImageView(images: [])
    }
}
