//
//  UIImage.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/11.
//

import UIKit

extension UIImage {
    func scale(to targetSize: CGSize) -> UIImage {
        let scaleFactor = min(targetSize.width / size.width, targetSize.height / size.height)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        let renderer = UIGraphicsImageRenderer(size: scaledSize)

        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
        
        return scaledImage
    }
}
