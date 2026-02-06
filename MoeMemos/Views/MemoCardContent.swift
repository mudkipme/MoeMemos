//
//  MemoCardContent.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
@preconcurrency import MarkdownUI
import Models
import MemoKit

@MainActor
struct MemoCardContent: View {
    private enum MemoResource: Identifiable {
        case images([any ResourcePresentable])
        case attachment(any ResourcePresentable)
        
        var id: String {
            switch self {
            case .images(let resources):
                return resources.map { resource in
                    if let stored = resource as? StoredResource {
                        return "\(stored.id)"
                    }
                    if let url = resource.url {
                        return url.absoluteString
                    }
                    return "\(resource.filename)|\(resource.createdAt.timeIntervalSince1970)"
                }.joined(separator: ",")
            case .attachment(let resource):
                if let stored = resource as? StoredResource {
                    return "\(stored.id)"
                }
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
            attachments.append(.images(imageResources))
        }
        
        attachments += otherResources.map { .attachment($0) }
        return attachments
    }
}
