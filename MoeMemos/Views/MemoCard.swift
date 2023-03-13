//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkdownUI

struct MemoCard: View {
    private enum MemoResource: Identifiable {
        case images([URL])
        case attachment(Resource)
        
        var id: String {
            switch self {
            case .images(let urls):
                return urls.map { $0.absoluteString }.joined(separator: ",")
            case .attachment(let resource):
                return "\(resource.id)"
            }
        }
    }
    
    let memo: Memo
    let defaultMemoVisilibity: MemosVisibility?
    let archivedViewModel: ArchivedMemoListViewModel?
    
    @EnvironmentObject private var memosManager: MemosManager
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showingEdit = false
    @State private var showingLegacyShareSheet = false
    @State private var showingDeleteConfirmation = false
    
    init(_ memo: Memo, archivedViewModel: ArchivedMemoListViewModel) {
        self.memo = memo
        self.archivedViewModel = archivedViewModel
        self.defaultMemoVisilibity = nil
    }
    
    init(_ memo: Memo, defaultMemoVisibility: MemosVisibility) {
        self.memo = memo
        self.defaultMemoVisilibity = defaultMemoVisibility
        self.archivedViewModel = nil
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if defaultMemoVisilibity != nil && memo.visibility != defaultMemoVisilibity {
                    Image(systemName: memo.visibility.iconName)
                        .foregroundColor(.secondary)
                }
                
                if memo.pinned {
                    Image(systemName: "flag.fill")
                        .renderingMode(.original)
                }
                
                Spacer()
                
                Menu {
                    if memo.rowStatus == .archived {
                        archivedMenu()
                    } else {
                        normalMenu()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .padding([.leading, .top, .bottom], 10)
                }
            }
            
            VStack {
                markdownRenderContent
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
        .padding([.top, .bottom], 5)
        .contextMenu {
            Button {
                UIPasteboard.general.setValue(memo.content, forPasteboardType: UTType.plainText.identifier)
            } label: {
                Label("memo.copy", systemImage: "doc.on.doc")
            }
        }
        .sheet(isPresented: $showingEdit) {
            MemoInput(memo: memo)
        }
        .confirmationDialog("memo.delete.confirm", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("memo.action.ok", role: .destructive) {
                Task {
                    try await archivedViewModel?.deleteMemo(id: memo.id)
                }
            }
            Button("memo.action.cancel", role: .cancel) {}
        }
    }
    
    private var markdownRenderContent: some View {
        Markdown(memo.content)
            .markdownImageProvider(.lazyImage(aspectRatio: 4 / 3))
            .markdownCodeSyntaxHighlighter(colorScheme == .dark ? .dark() : .light())
    }
    
    @ViewBuilder
    private func normalMenu() -> some View {
        Button {
            Task {
                do {
                    try await memosViewModel.updateMemoOrganizer(id: memo.id, pinned: !memo.pinned)
                } catch {
                    print(error)
                }
            }
        } label: {
            if memo.pinned {
                Label("memo.unpin", systemImage: "flag.slash")
            } else {
                Label("memo.pin", systemImage: "flag")
            }
        }
        Button {
            showingEdit = true
        } label: {
            Label("memo.edit", systemImage: "pencil")
        }
        if #available(iOS 16, *) {
            ShareLink(item: memo.content) {
                Label("memo.share", systemImage: "square.and.arrow.up")
            }
        } else {
            Button {
                showingLegacyShareSheet = true
            } label: {
                Label("memo.share", systemImage: "square.and.arrow.up")
            }
        }
        Button(role: .destructive, action: {
            Task {
                do {
                    try await memosViewModel.archiveMemo(id: memo.id)
                } catch {
                    print(error)
                }
            }
        }, label: {
            Label("memo.archive", systemImage: "archivebox")
        })
    }
    
    @ViewBuilder
    private func archivedMenu() -> some View {
        Button {
            Task {
                do {
                    try await archivedViewModel?.restoreMemo(id: memo.id)
                    try await memosViewModel.loadMemos()
                } catch {
                    print(error)
                }
            }
        } label: {
            Label("memo.restore", systemImage: "tray.and.arrow.up")
        }
        Button(role: .destructive, action: {
            showingDeleteConfirmation = true
        }, label: {
            Label("memo.delete", systemImage: "trash")
        })
    }
    
    private func renderTime() -> String {
        if Calendar.current.dateComponents([.day], from: memo.createdTs, to: .now).day! > 7 {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            return formatter.string(from: memo.createdTs)
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: memo.createdTs, relativeTo: .now)
    }
    
    private func resources() -> [MemoResource] {
        var attachments = [MemoResource]()
        if let resourceList = memo.resourceList, let memos = memosManager.memos {
            let imageResources = resourceList.filter { resource in
                resource.type.hasPrefix("image/")
            }
            let otherResources = resourceList.filter { resource in
                !resource.type.hasPrefix("image/")
            }
            
            if !imageResources.isEmpty {
                attachments.append(.images(imageResources.map { memos.url(for: $0) }))
            }
            
            attachments += otherResources.map { .attachment($0) }
        }
        
        return attachments
    }
}

struct MemoCard_Previews: PreviewProvider {
    static var previews: some View {
        MemoCard(Memo(id: 1, createdTs: .now.addingTimeInterval(-100), creatorId: 1, content: "Hello world\n\nThis is a **multiline** statement and thank you for everything.", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: .private, resourceList: nil), defaultMemoVisibility: .private)
            .environmentObject(MemosViewModel())
            .environmentObject(MemosManager())
    }
}
