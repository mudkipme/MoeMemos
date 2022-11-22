//
//  ImagePicker.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/23.
//

import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    let onComplete: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.delegate = context.coordinator
        return imagePicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.onComplete(image)
                }
            } else if let image = info[.originalImage] as? UIImage {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.onComplete(image)
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
