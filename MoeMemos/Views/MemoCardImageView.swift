//
//  MemoCardImageView.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/12/26.
//

import SwiftUI
import Account
import Models
import MemoKit
import DesignSystem

struct MemoCardImageView: View {
    let images: [any ResourcePresentable]

    @State private var imagePreviewURL: URL?
    @Environment(AccountManager.self) private var memosManager: AccountManager
    @Environment(\.openURL) private var openURL
    @State private var resolvedURLs = [String: URL]()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private func key(for resource: any ResourcePresentable, index: Int) -> String {
        if let stored = resource as? StoredResource {
            return "\(stored.id)"
        }
        if let url = resource.url {
            return url.absoluteString
        }
        return "\(resource.filename)|\(resource.createdAt.timeIntervalSince1970)|\(index)"
    }

    private func storedResource(from resource: any ResourcePresentable) -> StoredResource? {
        resource as? StoredResource
    }

    private func localURL(for resource: any ResourcePresentable, key: String) -> URL? {
        if let resolved = resolvedURLs[key] {
            return resolved
        }
        if let stored = storedResource(from: resource),
           let localPath = stored.localPath,
           FileManager.default.fileExists(atPath: localPath) {
            return URL(fileURLWithPath: localPath)
        }
        return nil
    }

    private func displayURL(for resource: any ResourcePresentable, key: String) -> URL? {
        if let local = localURL(for: resource, key: key) {
            return local
        }
        if storedResource(from: resource) != nil {
            // Stored resources should render from canonical local files only.
            return nil
        }
        return resource.url
    }

    private func resolveLocalFileIfNeeded(for resource: any ResourcePresentable, key: String) async {
        guard resolvedURLs[key] == nil else { return }
        guard let stored = storedResource(from: resource), let memos = memosManager.currentService else { return }
        if let localPath = stored.localPath, FileManager.default.fileExists(atPath: localPath) {
            resolvedURLs[key] = URL(fileURLWithPath: localPath)
            return
        }
        do {
            resolvedURLs[key] = try await memos.ensureLocalResourceFile(id: stored.id)
        } catch {
            return
        }
    }

    @ViewBuilder
    private func asyncImage(resource: any ResourcePresentable, key: String) -> some View {
        AsyncImage(url: displayURL(for: resource, key: key)) { image in
            image
                .resizable()
                .scaledToFill()
                .allowsHitTesting(false)
                .clipped()
        } placeholder: {
            ProgressView()
        }
        .task {
            await resolveLocalFileIfNeeded(for: resource, key: key)
        }
    }

    private func handleTap(resource: any ResourcePresentable, key: String) {
        if let local = localURL(for: resource, key: key) {
            imagePreviewURL = local
            return
        }

        if let stored = storedResource(from: resource), let memos = memosManager.currentService {
            Task {
                if let local = try? await memos.ensureLocalResourceFile(id: stored.id) {
                    resolvedURLs[key] = local
                    imagePreviewURL = local
                }
            }
            return
        }

        if let remoteURL = resource.url {
            Task {
                openURL(remoteURL)
            }
        }
    }

    @ViewBuilder
    private func imageItem(resource: any ResourcePresentable, key: String, aspectRatio: CGFloat, contentMode: ContentMode) -> some View {
        // Workaround of a SwiftUI Bug:
        // - The hit testing of image need to disabled to prevent affecting the menu button
        //   in the top right of memo card.
        // - I tried using `.contentShape(Rectangle())`, it does prevent image being tapped
        //   outside the image, but also prevent the menu button from hit.
        // - If I use `Color.clear` here, SwiftUI will optimize to pass the tap gesture to
        //   the image, and it will be untapable because hit testing is disabled on image.
        // - So I use some thing should be invisible to cheat SwiftUI not to optimize.
        //
        // Please submit a pull request if you have a better solution
        Color(white: 1, opacity: 0.00001).overlay {
            asyncImage(resource: resource, key: key)
        }
        .aspectRatio(aspectRatio, contentMode: contentMode)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .cornerRadius(8)
        .onTapGesture {
            handleTap(resource: resource, key: key)
        }
    }

    @ViewBuilder
    private var content: some View {
        if horizontalSizeClass == .regular {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 5)], spacing: 5) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, resource in
                    imageItem(resource: resource, key: key(for: resource, index: index), aspectRatio: 1.0, contentMode: .fill)
                }
            }
        } else {
            switch images.count {
            case 1:
                imageItem(resource: images[0], key: key(for: images[0], index: 0), aspectRatio: 16.0 / 9.0, contentMode: .fit)
            case 2...3:
                HStack(spacing: 5) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, resource in
                        imageItem(resource: resource, key: key(for: resource, index: index), aspectRatio: 1.0, contentMode: .fill)
                    }
                }
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
            default:
                LazyVGrid(columns: [GridItem(.adaptive(minimum: images.count == 4 ? 120 : 90, maximum: 150), spacing: 5)], spacing: 5) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, resource in
                        imageItem(resource: resource, key: key(for: resource, index: index), aspectRatio: 1.0, contentMode: .fill)
                    }
                }
            }
        }
    }

    var body: some View {
        content
            .padding([.bottom], 10)
            .fullScreenCover(item: $imagePreviewURL) { url in
                QuickLookPreview(selectedURL: url, urls: Array(Set(resolvedURLs.values)))
                    .edgesIgnoringSafeArea(.bottom)
                    .background(TransparentBackground())
            }
    }
}
