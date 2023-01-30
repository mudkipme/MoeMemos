//
//  ShareViewController.swift
//  MoeMemosShareExtension
//
//  Created by Mudkip on 2022/12/1.
//

import UIKit
import Social
import SwiftUI

class ShareViewController: SLComposeServiceViewController {
    
    let shareViewHostingController = UIHostingController(rootView: MoeMemosShareView())
    
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        if !contentText.isEmpty {
            return true
        }
        
        if let item = self.extensionContext!.inputItems.first as? NSExtensionItem, let attachments = item.attachments {
            for attachment in attachments {
                if attachment.canLoadObject(ofClass: NSURL.self) {
                    return true
                }
                
                if attachment.canLoadObject(ofClass: UIImage.self) {
                    return true
                }
            }
        }
        return false
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        Task {
            do {
                shareViewHostingController.view.translatesAutoresizingMaskIntoConstraints = false
                self.addChild(shareViewHostingController)
                self.view.addSubview(shareViewHostingController.view)
                NSLayoutConstraint.activate([
                    shareViewHostingController.view.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                    shareViewHostingController.view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
                ])
                try await handleShare()
                
                self.shareViewHostingController.rootView = MoeMemosShareView(alertType: .systemImage("checkmark.circle", "Memo saved."))
                try await Task.sleep(nanoseconds: 2_000_000_000)
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            } catch {
                self.shareViewHostingController.rootView = MoeMemosShareView(alertType: .systemImage("xmark.circle", error.localizedDescription))
                try await Task.sleep(nanoseconds: 2_000_000_000)
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    private func handleShare() async throws {
        let memos = try await getMemos()
        do {
            try await memos.loadStatus()
        } catch {
            print(error)
        }
        var resourceList = [Resource]()
        var contentTextList = [String]()
        contentTextList.append(contentText)
        
        if let item = self.extensionContext!.inputItems.first as? NSExtensionItem, let attachments = item.attachments {
            for attachment in attachments {
                if attachment.canLoadObject(ofClass: NSURL.self),
                   let url = try await attachment.loadObject(ofClass: NSURL.self),
                   let address = url.absoluteString {
                    contentTextList.append(address)
                }
                
                if attachment.canLoadObject(ofClass: UIImage.self),
                   let image = try await attachment.loadObject(ofClass: UIImage.self) {
                    var image = image
                    if image.size.height > 1024 || image.size.width > 1024 {
                        image = image.scale(to: CGSize(width: 1024, height: 1024))
                    }
                    
                    guard let data = image.jpegData(compressionQuality: 0.8) else { throw MemosError.invalidParams }
                    let response = try await memos.uploadResource(imageData: data, filename: "\(UUID().uuidString).jpg", contentType: "image/jpeg")
                    resourceList.append(response.data)
                }
            }
        }
        
        var content = contentTextList.joined(separator: "\n")
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            if resourceList.isEmpty {
                throw MemosError.invalidParams
            }
            content = "Save picture"
        }
        _ = try await memos.createMemo(data: MemosCreate.Input(content: content, visibility: nil, resourceIdList: resourceList.map { $0.id }))
    }
    
    private func getMemos() async throws -> Memos {
        guard let host = UserDefaults(suiteName: groupContainerIdentifier)?.string(forKey: memosHostKey) else {
            throw MemosError.notLogin
        }
        guard let hostURL = URL(string: host) else {
            throw MemosError.notLogin
        }
        
        let openId = UserDefaults(suiteName: groupContainerIdentifier)?.string(forKey: memosOpenIdKey)
        return Memos(host: hostURL, openId: openId)
    }
}
