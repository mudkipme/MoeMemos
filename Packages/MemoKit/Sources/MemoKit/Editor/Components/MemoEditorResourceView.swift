import SwiftUI
import Models

struct MemoEditorResourceView: View {
    var viewModel: MemoEditorViewModel

    var body: some View {
        let imageResources = viewModel.resourceList.filter { $0.mimeType.hasPrefix("image/") == true }
        let attachmentResources = viewModel.resourceList.filter { $0.mimeType.hasPrefix("image/") == false }

        if !viewModel.resourceList.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !imageResources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack {
                            ForEach(imageResources, id: \.id) { item in
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
