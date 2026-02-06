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

struct LazyImageProvider: @preconcurrency ImageProvider {
    let aspectRatio: CGFloat

    @MainActor func makeImage(url: URL?) -> some View {
        if let imageURL = makeURL(url) {
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } placeholder: {
                ProgressView()
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .cornerRadius(8)
        }
    }
    
    @MainActor func makeURL(_ url: URL?) -> URL? {
        guard let url = url else { return nil }
        let accountManager = Container.shared.accountManager()
        if url.host() == nil, let account = accountManager.currentAccount, case let .memosV0(host: host, id: _, accessToken: _) = account, let hostURL = URL(string: host) {
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
