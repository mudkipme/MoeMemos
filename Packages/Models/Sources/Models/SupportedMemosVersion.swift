//
//  SupportedMemosVersion.swift
//
//
//  Created by Codex on 2026/2/11.
//

import Foundation

public enum SupportedMemosVersion {
    public static let minimumV0 = "0.21.0"
    public static let minimumV1 = "0.26.0"
    public static let maximumV1 = "0.26.2"

    public static func localizedSupportedVersionsMessage() -> String {
        let format = NSLocalizedString("compat.supported-versions", comment: "Supported Memos versions for Moe Memos")
        return String.localizedStringWithFormat(format, minimumV0, minimumV1, maximumV1)
    }
}
