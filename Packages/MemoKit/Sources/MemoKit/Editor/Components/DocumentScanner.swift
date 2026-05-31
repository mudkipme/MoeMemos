import SwiftUI
import UIKit

#if canImport(VisionKit) && os(iOS) && !targetEnvironment(macCatalyst)
@preconcurrency import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    enum Result {
        case success([UIImage])
        case cancelled
        case failure(Swift.Error)
    }

    let onComplete: (Result) -> Void

    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScanner

        init(parent: DocumentScanner) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            controller.dismiss(animated: true) { [parent] in
                parent.onComplete(.success(images))
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [parent] in
                parent.onComplete(.cancelled)
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Swift.Error) {
            controller.dismiss(animated: true) { [parent] in
                parent.onComplete(.failure(error))
            }
        }
    }
}
#endif
