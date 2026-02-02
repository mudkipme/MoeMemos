import SwiftUI
import Models

struct MemoEditorResourceView: View {
    var viewModel: MemoEditorViewModel

    var body: some View {
        if !viewModel.resourceList.isEmpty || viewModel.imageUploading {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(viewModel.resourceList, id: \.id) { resource in
                        if resource.mimeType.hasPrefix("image/") == true {
                            ResourceCard(resource: resource, resourceManager: viewModel)
                        } else {
                            Attachment(resource: resource)
                        }
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
    }
}
