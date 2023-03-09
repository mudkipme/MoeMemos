//
//  Highlighter.swift
//  MoeMemos
//
//  Created by Purkylin King on 2023/3/9.
//

import Highlightr
import SwiftUI
import MarkdownUI

class Highlighter: CodeSyntaxHighlighter {
    
    func highlightCode(_ code: String, language: String?) -> Text {
        guard let highlightr = Highlightr() else { fatalError("") }
        highlightr.setTheme(to: "github")
        let result = highlightr.highlight(code, as: language?.lowercased()) ?? NSAttributedString()
        guard let attrString = try? AttributedString(result, including: \.uiKit) else {
            fatalError("Convert failed")
        }
        return Text(attrString)
    }
}

extension CodeSyntaxHighlighter where Self == Highlighter {
    // TODO: support dark mode
    static func `default`() -> Self {
        return Highlighter()
    }
}
