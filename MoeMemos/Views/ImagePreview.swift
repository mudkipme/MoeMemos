//
//  ImageViewer.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/11.
//

import SwiftUI

struct ImageViewer: View {
    let imageURL: URL
    @Environment(\.dismiss) var dismiss
    @State var scale: CGFloat = 1.0
    @State var lastScale: CGFloat = 1
    @State var offset: CGSize = .zero
    @State var gestureEnded = false
    
    var body: some View {
        Color.black.overlay {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    display(image: image)
                } else if case .failure = phase {
                    Image(systemName: "xmark.circle.fill")
                } else {
                    ProgressView()
                }
            }
        }
        .onTapGesture {
            dismiss()
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    @ViewBuilder
    private func display(image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged({ value in
                        gestureEnded = false
                        offset = value.translation
                    })
                    .onEnded({ value in
                        gestureEnded = true
                        offset = .zero
                    })
            )
            .gesture(
                MagnificationGesture()
                    .onChanged({ value in
                        gestureEnded = false
                        scale = value * lastScale
                    })
                    .onEnded({ value in
                        gestureEnded = true
                        scale = max(1.0, min(value, 2.0))
                        lastScale = scale
                    })
            )
            .animation(gestureEnded ? .easeOut(duration: 0.25) : .linear(duration: 0.1), value: scale)
            .animation(gestureEnded ? .easeOut(duration: 0.25) : .linear(duration: 0.1), value: offset)
    }
}

struct ImageViewer_Previews: PreviewProvider {
    static var previews: some View {
        ImageViewer(imageURL: URL(string: "https://memos.moe/memos.png")!)
    }
}
