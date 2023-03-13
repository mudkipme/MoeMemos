//
//  LazyImageProvider.swift
//  MoeMemos
//
//  Created by Purkylin King on 2023/3/8.
//

import SwiftUI
import MarkdownUI
import Kingfisher

struct LazyImageProvider: ImageProvider {
    let aspectRatio: CGFloat

    @MainActor
    func makeImage(url: URL?) -> some View {
        KFImage(makeURL(url)).placeholder { _ in
            ProgressView()
        }
        .resizable()
        .aspectRatio(self.aspectRatio, contentMode: .fit)
    }
    
    @MainActor
    func makeURL(_ url: URL?) -> URL? {
        guard let url = url else { return nil }
        if url.host == nil, let hostURL = MemosManager.shared.hostURL {
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
