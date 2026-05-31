import XCTest
import UIKit
@testable import MemoKit

final class MemoKitTests: XCTestCase {
    func testScannedDocumentPDFBuilderCreatesPDFData() throws {
        let images = [
            makeImage(size: CGSize(width: 100, height: 160), color: .red),
            makeImage(size: CGSize(width: 120, height: 80), color: .blue)
        ]

        let data = try ScannedDocumentPDFBuilder.makePDFData(from: images)

        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "%PDF")
    }

    func testScannedDocumentPDFBuilderRejectsEmptyInput() {
        XCTAssertThrowsError(try ScannedDocumentPDFBuilder.makePDFData(from: [])) { error in
            XCTAssertEqual(error as? ScannedDocumentPDFBuilder.Error, .emptyDocument)
        }
    }

    private func makeImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
