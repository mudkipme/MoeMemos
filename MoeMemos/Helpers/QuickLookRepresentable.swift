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

  func makeUIViewController(context: Context) -> UINavigationController {
    let controller = AppQLPreviewController()
    controller.dataSource = context.coordinator
    controller.delegate = context.coordinator
    let nav = UINavigationController(rootViewController: controller)
    return nav
  }

  func updateUIViewController(
    _: UINavigationController, context _: Context
  ) {}

  func makeCoordinator() -> Coordinator {
    return Coordinator(parent: self)
  }

  class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    let parent: QuickLookPreview

    init(parent: QuickLookPreview) {
      self.parent = parent
    }

    func numberOfPreviewItems(in _: QLPreviewController) -> Int {
      return parent.urls.count
    }

    func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
      return parent.urls[index] as QLPreviewItem
    }

    func previewController(_: QLPreviewController, editingModeFor _: QLPreviewItem) -> QLPreviewItemEditingMode {
      .createCopy
    }
  }
}

class AppQLPreviewController: QLPreviewController {
  private var closeButton: UIBarButtonItem {
      .init(
        title: NSLocalizedString("Done", comment: ""),
        style: .plain,
        target: self,
        action: #selector(onCloseButton)
      )
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if UIDevice.current.userInterfaceIdiom != .pad {
      navigationItem.rightBarButtonItem = closeButton
    }
  }

  @objc private func onCloseButton() {
    dismiss(animated: true)
  }
}
