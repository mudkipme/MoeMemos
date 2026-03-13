//
//  VideoThumbnailGenerator.swift
//  MoeMemos
//
//  Created by Bexon Pak on 12.03.26.
//

import AVFoundation
import UIKit

enum VideoThumbnailGenerator {
    
    /// Retrieve thumbnails from online video URLs (without downloading full videos)
    /// - Parameters:
    ///   - url: Video URL string
    ///   - seconds: Capture time point (default: 0 seconds, i.e., first frame)
    static func generateThumbnail(
        from url: URL?,
        at seconds: Double = 0
    ) async throws -> UIImage {
        guard let url else {
            throw ThumbnailError.invalidURL
        }
        
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Only request precise timestamps; do not generate intermediate frames.
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        // Set maximum size (reduce memory usage)
        imageGenerator.maximumSize = CGSize(width: 720, height: 720)
        
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, actualTime, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = cgImage else {
                    continuation.resume(throwing: ThumbnailError.generationFailed)
                    return
                }
                
                let thumbnail = UIImage(cgImage: cgImage)
                continuation.resume(returning: thumbnail)
            }
        }
    }
    
    enum ThumbnailError: Error {
        case invalidURL
        case generationFailed
    }
}
