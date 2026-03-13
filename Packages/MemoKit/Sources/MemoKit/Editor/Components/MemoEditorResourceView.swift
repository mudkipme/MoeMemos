import SwiftUI
import Models

struct MemoEditorResourceView: View {
    var viewModel: MemoEditorViewModel

    var body: some View {
        let mediaResources = viewModel.resourceList.filter {
            $0.mimeType.hasPrefix("image/") == true || $0.mimeType.hasPrefix("video/") == true
        }
        let attachmentResources = viewModel.resourceList.filter {
            $0.mimeType.hasPrefix("image/") == false && $0.mimeType.hasPrefix("video/") == false
        }

        if !viewModel.resourceList.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !mediaResources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack {
                            ForEach(mediaResources, id: \.id) { item in
                                ResourceCard(resource: item, resourceManager: viewModel)
                            }
                        }
                        .frame(height: 80)
                        .padding([.leading, .trailing, .bottom])
                    }
                }

                if !attachmentResources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack {
                            ForEach(attachmentResources, id: \.id) { item in
                                Attachment(resource: item, resourceManager: viewModel)
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
