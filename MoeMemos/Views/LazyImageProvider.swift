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

    func makeImage(url: URL?) -> some View {
      KFImage(url).placeholder { _ in
          Color(.secondarySystemBackground)
      }
      .resizable()
      .aspectRatio(self.aspectRatio, contentMode: .fill)
    }
}

extension ImageProvider where Self == LazyImageProvider {
    static func lazyImage(aspectRatio: CGFloat) -> Self {
        LazyImageProvider(aspectRatio: aspectRatio)
    }
}
