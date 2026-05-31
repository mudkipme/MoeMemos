import UIKit

public enum ScannedDocumentPDFBuilder {
    public enum Error: LocalizedError, Equatable {
        case emptyDocument

        public var errorDescription: String? {
            switch self {
            case .emptyDocument:
                "Scanned document contains no pages."
            }
        }
    }

    public static func makePDFData(from images: [UIImage]) throws -> Data {
        guard !images.isEmpty else {
            throw Error.emptyDocument
        }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: images[0].size))
        return renderer.pdfData { context in
            for image in images {
                let pageBounds = CGRect(origin: .zero, size: image.size)
                context.beginPage(withBounds: pageBounds, pageInfo: [:])
                image.draw(in: pageBounds)
            }
        }
    }
}
