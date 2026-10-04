//
//  Resources.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/10.
//

import SwiftUI
import MemoKit
import Models

fileprivate let columns = [GridItem(.adaptive(minimum: 125, maximum: 200), spacing: 10), GridItem(.adaptive(minimum: 125, maximum: 200), spacing: 10)]

fileprivate enum ResourceSection: String, CaseIterable, Identifiable {
    case image = "resources.section.image"
    case other = "resources.section.other"

    var id: String { rawValue }
    var title: LocalizedStringKey { LocalizedStringKey(rawValue) }
}

struct Resources: View {
    @State private var viewModel = ResourceListViewModel()
    @State private var loading = true
    @State private var loadError: String?
    @State private var section: ResourceSection = .image

    private var mediaResources: [StoredResource] {
        viewModel.resourceList.filter { $0.mimeType.hasPrefix("image/") || $0.mimeType.hasPrefix("video/") }
    }

    private var otherResources: [StoredResource] {
        viewModel.resourceList.filter { !$0.mimeType.hasPrefix("image/") && !$0.mimeType.hasPrefix("video/") }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("resources.section", selection: $section) {
                ForEach(ResourceSection.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if loading && viewModel.resourceList.isEmpty {
                ProgressView("common.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, viewModel.resourceList.isEmpty {
                ContentUnavailableView {
                    Label("common.load-failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("common.retry") { Task { await loadContent() } }
                }
            } else if section == .image {
                if mediaResources.isEmpty {
                    ContentUnavailableView("resources.empty.images", systemImage: "photo.on.rectangle")
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns) {
                            ForEach(mediaResources) { item in
                                ResourceCard(resource: item, resourceManager: viewModel)
                            }
                        }
                        .padding([.horizontal, .bottom])
                    }
                }
            } else {
                if otherResources.isEmpty {
                    ContentUnavailableView("resources.empty.attachments", systemImage: "paperclip")
                } else {
                    List(otherResources) { item in
                        Attachment(resource: item)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        try await viewModel.deleteResource(id: item.id)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("resources")
        .task {
            await loadContent()
        }
    }

    private func loadContent() async {
        loading = true
        loadError = nil
        defer { loading = false }
        do {
            try await viewModel.loadResources()
        } catch {
            loadError = error.localizedDescription
        }
    }

}
