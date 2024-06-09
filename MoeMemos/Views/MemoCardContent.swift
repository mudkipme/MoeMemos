//
//  MemoCardContent.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
@preconcurrency import MarkdownUI
import MemosV0Service
import Account

@MainActor
struct MemoCardContent: View {
    private enum MemoResource: Identifiable {
        case images([URL])
        case attachment(MemosResource)
        
        var id: String {
            switch self {
            case .images(let urls):
                return urls.map { $0.absoluteString }.joined(separator: ",")
            case .attachment(let resource):
                return "\(resource.id)"
            }
        }
    }

    let memo: MemosMemo
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
        if let resourceList = memo.resourceList, let memos = memosManager.currentService {
            let imageResources = resourceList.filter { resource in
                resource._type?.hasPrefix("image/") == true
            }
            let otherResources = resourceList.filter { resource in
                !(resource._type?.hasPrefix("image/") == true)
            }
            
            if !imageResources.isEmpty {
                attachments.append(.images(imageResources.map { memos.url(for: $0) }))
            }
            
            attachments += otherResources.map { .attachment($0) }
        }
        
        return attachments
    }
}
