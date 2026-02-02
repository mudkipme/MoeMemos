import SwiftUI
import Models

struct MemoEditorResourceView: View {
    var viewModel: MemoEditorViewModel

    var body: some View {
        let imageResources = viewModel.resourceList.filter { $0.mimeType.hasPrefix("image/") == true }
        let attachmentResources = viewModel.resourceList.filter { $0.mimeType.hasPrefix("image/") == false }

        if !viewModel.resourceList.isEmpty || viewModel.imageUploading {
            VStack(alignment: .leading, spacing: 8) {
                if !imageResources.isEmpty || viewModel.imageUploading {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack {
                            ForEach(imageResources, id: \.id) { resource in
                                ResourceCard(resource: resource, resourceManager: viewModel)
                            }
                            if viewModel.imageUploading {
                                Color.clear
                                    .scaledToFill()
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                        }
                        .frame(height: 80)
                        .padding([.leading, .trailing, .bottom])
                    }
                }

                if !attachmentResources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack {
                            ForEach(attachmentResources, id: \.id) { resource in
                                Attachment(resource: resource)
                                    .frame(maxWidth: 200, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: 32)
                    .padding([.leading, .trailing, .bottom])
                }
            }
        }
    }
}
