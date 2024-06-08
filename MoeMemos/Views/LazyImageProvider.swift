//
//  LazyImageProvider.swift
//  MoeMemos
//
//  Created by Purkylin King on 2023/3/8.
//

import SwiftUI
import MarkdownUI
import Account
import Factory

struct LazyImageProvider: ImageProvider {
    let aspectRatio: CGFloat
    @Injected(\.accountManager) private var accountManager

    func makeImage(url: URL?) -> some View {
        if let url = makeURL(url) {
            MemoCardImageView(images: [url])
        }
    }
    
    func makeURL(_ url: URL?) -> URL? {
        guard let url = url else { return nil }
        if url.host == nil, let hostURL = accountManager.currentService?.hostURL {
            return hostURL.appendingPathComponent(url.path)
        }
        return url
    }
}

extension ImageProvider where Self == LazyImageProvider {
    static func lazyImage(aspectRatio: CGFloat) -> Self {
        LazyImageProvider(aspectRatio: aspectRatio)
    }
}
