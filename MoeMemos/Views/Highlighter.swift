//
//  Highlighter.swift
//  MoeMemos
//
//  Created by Purkylin King on 2023/3/9.
//

import Highlightr
import SwiftUI
import MarkdownUI

@MainActor
class Highlighter: CodeSyntaxHighlighter {
    static let dark = Highlighter(colorScheme: .dark)
    static let light = Highlighter(colorScheme: .light)
    
    let colorScheme: ColorScheme
    
    init(colorScheme: ColorScheme) {
        self.colorScheme = colorScheme
    }
    
    nonisolated func highlightCode(_ code: String, language: String?) -> Text {
        guard let highlightr = Highlightr() else { fatalError("") }
        highlightr.setTheme(to: colorScheme == .dark ? "atom-one-dark-reasonable" : "github")
        let result = highlightr.highlight(code, as: language?.lowercased()) ?? NSAttributedString()
        guard let attrString = try? AttributedString(result, including: \.uiKit) else {
            fatalError("Convert failed")
        }
        return Text(attrString)
    }
}

@MainActor
extension CodeSyntaxHighlighter where Self == Highlighter {
    static func light() -> Self {
        return .light
    }
    
    static func dark() -> Self {
        return .dark
    }
}
