//
//  AsyncThumbnailImage.swift
//  MoeMemos
//
//  Created by Bexon Pak on 12.03.26.
//

import SwiftUI
import AVFoundation

public struct AsyncThumbnailImage: View {
    let videoURL: URL?
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    
    public init(videoURL: URL?, thumbnail: UIImage? = nil, isLoading: Bool = false) {
        self.videoURL = videoURL
        self.thumbnail = thumbnail
        self.isLoading = isLoading
    }
    
    public var body: some View {
        Group {
            if thumbnail != nil {
                ZStack(alignment: .center) {
                    thumbnailLayer
                    playButton
                }
            } else if isLoading {
                ProgressView()
            } else {
                Color.gray
            }
        }
        .onAppear {
            Task {
                await loadThumbnail()
            }
        }
    }
    
    @ViewBuilder
    private var thumbnailLayer: some View {
        if let thumbnail = thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if isLoading {
            ProgressView()
        } else {
            Color.gray.opacity(0.3)
        }
    }
    
    @ViewBuilder
    private var playButton: some View {
        if #available(iOS 26.0, *) {
            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .frame(width: 24, height: 24)
                .foregroundStyle(.black)
                .padding(14)
                .symbolRenderingMode(.hierarchical)
                .glassEffect(.clear)
                .opacity(thumbnail != nil ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: thumbnail)
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .frame(width: 24, height: 24)
                .foregroundStyle(.black)
                .padding(14)
                .symbolRenderingMode(.hierarchical)
                .background(Circle().fill(.ultraThinMaterial))
                .opacity(thumbnail != nil ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: thumbnail)
        }
    }
    
    private func loadThumbnail() async {
        guard thumbnail == nil, !isLoading else { return }
        isLoading = true
        
        do {
            let image = try await VideoThumbnailGenerator.generateThumbnail(from: videoURL)
            self.thumbnail = image
        } catch {
            print(error)
        }
        self.isLoading = false
    }
}
