//
//  MemoInputResourceView.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/1/24.
//

import SwiftUI

struct MemoInputResourceView: View {
    var viewModel: MemoInputViewModel
    
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

struct MemoInputResourceView_Previews: PreviewProvider {
    static var previews: some View {
        MemoInputResourceView(viewModel: MemoInputViewModel())
    }
}
