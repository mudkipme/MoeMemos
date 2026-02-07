//
//  MemoCardContent.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
import MarkdownView
import Markdown
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
    let toggleTaskItem: ((ListItem) async -> Void)?
    @Environment(\.colorScheme) var colorScheme
    @State private var cachedRawMarkdown: String
    @State private var cachedPreprocessedMarkdown: String

    init(memo: any MemoPresentable, toggleTaskItem: ((ListItem) async -> Void)? = nil) {
        self.memo = memo
        self.toggleTaskItem = toggleTaskItem
        let content = memo.content
        _cachedRawMarkdown = State(initialValue: content)
        _cachedPreprocessedMarkdown = State(initialValue: MemoMarkdownPreprocessor.preprocess(content))
    }
    
    var body: some View {
        
        
        VStack(alignment: .leading) {
            
            MarkdownView(cachedPreprocessedMarkdown)
                .taskListMarker { listItem in
                    Image(systemName: listItem.checkbox == .checked ? "checkmark.square.fill" : "square")
                        .symbolRenderingMode(.hierarchical)
                        .imageScale(.medium)
                        .onTapGesture {
                            Task {
                                await toggleTaskItem?(listItem)
                            }
                        }
                }
            
            ForEach(resources()) { content in
                if case let .images(urls) = content {
                    MemoCardImageView(images: urls)
                }
                if case let .attachment(resource) = content {
                    Attachment(resource: resource)
                }
            }
        }
        .onChange(of: memo.content) { _, newContent in
            guard newContent != cachedRawMarkdown else {
                return
            }
            cachedRawMarkdown = newContent
            cachedPreprocessedMarkdown = MemoMarkdownPreprocessor.preprocess(newContent)
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
