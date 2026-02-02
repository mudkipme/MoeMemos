import QuickLook
import SwiftUI
import UIKit

public struct QuickLookPreview: UIViewControllerRepresentable {
  public let selectedURL: URL
  public let urls: [URL]

  public init(selectedURL: URL, urls: [URL]) {
    self.selectedURL = selectedURL
    self.urls = urls
  }

  public func makeUIViewController(context _: Context) -> UIViewController {
    return AppQLPreviewController(selectedURL: selectedURL, urls: urls)
  }

  public func updateUIViewController(
    _: UIViewController, context _: Context
  ) {}
}

class AppQLPreviewController: UIViewController {
  let selectedURL: URL
  let urls: [URL]

  var qlController: QLPreviewController?

  init(selectedURL: URL, urls: [URL]) {
    self.selectedURL = selectedURL
    self.urls = urls
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if qlController == nil {
      qlController = QLPreviewController()
      qlController?.dataSource = self
      qlController?.delegate = self
      qlController?.currentPreviewItemIndex = urls.firstIndex(of: selectedURL) ?? 0
      present(qlController!, animated: true)
    }
  }
}

extension AppQLPreviewController: QLPreviewControllerDataSource {
  nonisolated func numberOfPreviewItems(in _: QLPreviewController) -> Int {
    return urls.count
  }

  nonisolated func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    return urls[index] as QLPreviewItem
  }
}

extension AppQLPreviewController: QLPreviewControllerDelegate {
  nonisolated func previewController(_: QLPreviewController, editingModeFor _: QLPreviewItem) -> QLPreviewItemEditingMode {
    .createCopy
  }

  nonisolated func previewControllerWillDismiss(_: QLPreviewController) {
      DispatchQueue.main.async {
          self.dismiss(animated: true)
      }
  }

  nonisolated func previewControllerDidDismiss(_ controller: QLPreviewController) {
      DispatchQueue.main.async {
          self.dismiss(animated: true)
      }
  }
}

public struct TransparentBackground: UIViewControllerRepresentable {
  public init() {}

  public func makeUIViewController(context _: Context) -> UIViewController {
    return TransparentController()
  }

  public func updateUIViewController(_: UIViewController, context _: Context) {}

  class TransparentController: UIViewController {
    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .clear
    }

    override func willMove(toParent parent: UIViewController?) {
      super.willMove(toParent: parent)
      parent?.view?.backgroundColor = .clear
      parent?.modalPresentationStyle = .overCurrentContext
    }
  }
}
