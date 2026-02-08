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
    @State private var section: ResourceSection = .image

    private var imageResources: [StoredResource] {
        viewModel.resourceList.filter { $0.mimeType.hasPrefix("image/") }
    }

    private var otherResources: [StoredResource] {
        viewModel.resourceList.filter { !$0.mimeType.hasPrefix("image/") }
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

            if section == .image {
                if imageResources.isEmpty {
                    ContentUnavailableView("resources.empty.images", systemImage: "photo.on.rectangle")
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns) {
                            ForEach(imageResources) { item in
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
            do {
                try await viewModel.loadResources()
            } catch {
                print(error)
            }
        }
    }
}
