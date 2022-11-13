//
//  MemoCard.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import SwiftUI
import UniformTypeIdentifiers

struct MemoCard: View {
    private enum MemoContent: Identifiable {
        case text(AttributedString)
        case image(URL)
        case attachment(Resource)
        
        var id: String {
            switch self {
            case .text(let attributedString):
                return String(attributedString.characters)
            case .image(let url):
                return url.absoluteString
            case .attachment(let resource):
                return "\(resource.id)"
            }
        }
    }
    
    let memo: Memo
    let archivedViewModel: ArchivedMemoListViewModel?
    
    @EnvironmentObject private var memosManager: MemosManager
    @EnvironmentObject private var memosViewModel: MemosViewModel
    @State private var showingEdit = false
    @State private var showingLegacyShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var imagePreviewURL: URL?
    
    init(_ memo: Memo, archivedViewModel: ArchivedMemoListViewModel? = nil) {
        self.memo = memo
        self.archivedViewModel = archivedViewModel
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(renderTime())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
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
            
            ForEach(renderContent()) { content in
                if case let .text(attributedString) = content {
                    Text(attributedString)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if case let .image(url) = content {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onTapGesture {
                                imagePreviewURL = url
                            }
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 160, height: 160)
                    .cornerRadius(8)
                    .padding([.bottom], 10)
                    .clipped()
                }
                if case let .attachment(resource) = content {
                    Attachment(resource: resource)
                }
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.setValue(memo.content, forPasteboardType: UTType.plainText.identifier)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .padding([.top, .bottom], 5)
        .sheet(isPresented: $showingEdit) {
            MemoInput(memo: memo)
        }
        .confirmationDialog("Delete this memo?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Yes", role: .destructive) {
                Task {
                    try await archivedViewModel?.deleteMemo(id: memo.id)
                }
            }
            Button("No", role: .cancel) {}
        }
        .fullScreenCover(item: $imagePreviewURL) { url in
            if let url = url {
                ImageViewer(imageURL: url)
            }
        }
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
                Label("Unpin", systemImage: "flag.slash")
            } else {
                Label("Pin", systemImage: "flag")
            }
        }
        Button {
            showingEdit = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        if #available(iOS 16, *) {
            ShareLink(item: memo.content) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } else {
            Button {
                showingLegacyShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
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
            Label("Archive", systemImage: "archivebox")
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
            Label("Restore", systemImage: "tray.and.arrow.up")
        }
        Button(role: .destructive, action: {
            showingDeleteConfirmation = true
        }, label: {
            Label("Delete", systemImage: "trash")
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
    
    private func renderContent() -> [MemoContent] {
        var contents = [MemoContent]()

        do {
            let attributedString = try AttributedString(markdown: memo.content, options: AttributedString.MarkdownParsingOptions(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace))

            var lastAttributed = AttributedString()
            for i in attributedString.runs {
                if let imageURL = i.imageURL {
                    if !lastAttributed.characters.isEmpty {
                        contents.append(.text(lastAttributed))
                        lastAttributed = AttributedString()
                    }
                    
                    var url = imageURL
                    if url.host == nil, let hostURL = memosManager.hostURL {
                        url = hostURL.appendingPathComponent(url.path)
                    }
                    contents.append(.image(url))
                    continue
                }
                lastAttributed += attributedString[i.range]
            }
            
            if !lastAttributed.characters.isEmpty {
                contents.append(.text(lastAttributed))
            }
            
        } catch {
            contents = [.text(AttributedString(memo.content))]
        }
        
        if let resourceList = memo.resourceList, let hostURL = memosManager.hostURL {
            contents += resourceList.map { resource in
                if resource.type.hasPrefix("image/") {
                    return .image(hostURL.appendingPathComponent(resource.path()))
                } else {
                    return .attachment(resource)
                }
            }
        }
        
        return contents
    }
}

struct MemoCard_Previews: PreviewProvider {
    static var previews: some View {
        MemoCard(Memo(id: 1, createdTs: .now.addingTimeInterval(-100), creatorId: 1, content: "Hello world\n\nThis is a **multiline** statement and thank you for everything.", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: .private, resourceList: nil))
            .environmentObject(MemosViewModel())
            .environmentObject(MemosManager())
    }
}
