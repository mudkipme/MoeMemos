// Copyright (C) 2023 Thomas Ricouard
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import QuickLook
import SwiftUI
import UIKit

struct QuickLookPreview: UIViewControllerRepresentable {
  let selectedURL: URL
  let urls: [URL]

  func makeUIViewController(context _: Context) -> UIViewController {
    return AppQLPreviewController(selectedURL: selectedURL, urls: urls)
  }

  func updateUIViewController(
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

struct TransparentBackground: UIViewControllerRepresentable {
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
