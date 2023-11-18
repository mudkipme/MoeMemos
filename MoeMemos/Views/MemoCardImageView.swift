//
//  MemoCardImageView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/12/26.
//

import SwiftUI
import QuickLook
import Account

struct MemoCardImageView: View {
    let images: [URL]
    
    @State private var imagePreviewURL: URL?
    @Environment(AccountManager.self) private var memosManager: AccountManager
    @State private var downloads = [URL: URL]()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @ViewBuilder
    private func asyncImage(url: URL) -> some View {
        if let downloaded = downloads[url] {
            AsyncImage(url: downloaded) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .allowsHitTesting(false)
                    .clipped()
            } placeholder: {
                ProgressView()
            }
        } else {
            ProgressView()
                .task { @MainActor in
                    do {
                        if downloads[url] == nil, let memos = memosManager.currentService {
                            downloads[url] = try await memos.download(url: url)
                        }
                    } catch {}
                }
        }
    }
    
    @ViewBuilder
    private func imageItem(url: URL, aspectRatio: CGFloat, contentMode: ContentMode) -> some View {
        // Workaround of a SwiftUI Bug:
        // - The hit testing of image need to disabled to prevent affecting the menu button
        //   in the top right of memo card.
        // - I tried using `.contentShape(Rectangle())`, it does prevent image being tapped
        //   outside the image, but also prevent the menu button from hit.
        // - If I use `Color.clear` here, SwiftUI will optimize to pass the tap gesture to
        //   the image, and it will be untapable because hit testing is disabled on image.
        // - So I use some thing should be invisible to cheat SwiftUI not to optimize.
        //
        // Please submit a pull request if you have a better solution
        Color(white: 1, opacity: 0.00001).overlay {
            asyncImage(url: url)
        }
        .aspectRatio(aspectRatio, contentMode: contentMode)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .cornerRadius(8)
        .onTapGesture {
            imagePreviewURL = downloads[url]
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if horizontalSizeClass == .regular {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 5)], spacing: 5) {
                ForEach(images) { url in
                    imageItem(url: url, aspectRatio: 1.0, contentMode: .fill)
                }
            }
        } else {
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
    }
    
    var body: some View {
        content
            .padding([.bottom], 10)
            .fullScreenCover(item: $imagePreviewURL) { url in
                QuickLookPreview(selectedURL: url, urls: images.compactMap { downloads[$0] })
                    .edgesIgnoringSafeArea(.bottom)
                    .background(TransparentBackground())
            }
    }
}

struct MemoCardImageView_Previews: PreviewProvider {
    static var previews: some View {
        MemoCardImageView(images: [])
    }
}
