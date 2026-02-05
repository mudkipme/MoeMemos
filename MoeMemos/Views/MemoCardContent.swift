//
//  MemoCardContent.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
@preconcurrency import MarkdownUI
import Models
import Account
import MemoKit

@MainActor
struct MemoCardContent: View {
    private enum MemoResource: Identifiable {
        case images([ImageInfo])
        case attachment(any ResourcePresentable)
        
        var id: String {
            switch self {
            case .images(let pairs):
                return pairs.map { $0.url.absoluteString }.joined(separator: ",")
            case .attachment(let resource):
                if let url = resource.url {
                    return url.absoluteString
                }
                return "\(resource.filename)|\(resource.createdAt.timeIntervalSince1970)"
            }
        }
    }

    let memo: any MemoPresentable
    let toggleTaskItem: ((TaskListMarkerConfiguration) async -> Void)?
    @Environment(\.colorScheme) var colorScheme
    @Environment(AccountManager.self) private var memosManager: AccountManager
    
    var body: some View {
        VStack(alignment: .leading) {
            MarkdownView(memo.content)
                .markdownImageProvider(.lazyImage(aspectRatio: 4 / 3))
                .markdownCodeSyntaxHighlighter(colorScheme == .dark ? .dark() : .light())
                .markdownTaskListMarker(BlockStyle { configuration in
                    Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                        .symbolRenderingMode(.hierarchical)
                        .imageScale(.medium)
                        .relativeFrame(minWidth: .em(1), alignment: .leading)
                        .onTapGesture {
                            Task {
                                await toggleTaskItem?(configuration)
                            }
                        }
                })
            
            ForEach(resources()) { content in
                if case let .images(urls) = content {
                    MemoCardImageView(images: urls)
                }
                if case let .attachment(resource) = content {
                    Attachment(resource: resource)
                }
            }
        }
    }
    
    private func resources() -> [MemoResource] {
        var attachments = [MemoResource]()
        let resourceList = memo.attachments
        let imageResources = resourceList.filter { resource in
            resource.mimeType.hasPrefix("image/") == true
        }
        let otherResources = resourceList.filter { resource in
            !(resource.mimeType.hasPrefix("image/") == true)
        }
        
        if !imageResources.isEmpty {
            attachments.append(.images(imageResources.compactMap { resource in
                guard let url = resource.url else { return nil }
                return ImageInfo(url: url, mimeType: resource.mimeType)
            }))
        }
        
        attachments += otherResources.map { .attachment($0) }
        return attachments
    }
}
