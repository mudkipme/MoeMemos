//
//  PhotoPicker.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/11.
//

import PhotosUI
import SwiftUI

@available(iOS, deprecated: 16.0, message: "Use PhotosPicker")
struct LegacyPhotoPicker: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    let selectionLimit = 1

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LegacyPhotoPicker

        init(_ parent: LegacyPhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            var images = [UIImage]()
            
            let dispatchGroup = DispatchGroup()
            for result in results {
                dispatchGroup.enter()
                
                let provider = result.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let image = image as? UIImage {
                            images.append(image)
                        }
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) { [weak self] in
                    self?.parent.onComplete(images)
                }
            }
        }
    }
}
