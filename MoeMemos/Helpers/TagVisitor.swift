//
//  TagVisitor.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/21.
//

import Foundation
import Markdown

struct TagVisitor: MarkupWalker {
    let hashPattern = try! NSRegularExpression(pattern: "#([^\\s#]+)")
    var tags: [String] = []

    mutating func visitText(_ node: Markdown.Text) -> () {
        let fullRange = NSRange(location: 0, length: node.plainText.utf16.count)
        hashPattern.enumerateMatches(in: node.plainText, range: fullRange) { result, _, _ in
            if let matchRange = result?.range {
                if !isInsideCodeBlock(node) && !isInsideLink(node) {
                    let tag = node.plainText[Range(matchRange, in: node.plainText)!]
                    tags.append(String(tag))
                }
            }
        }
    }
    
    func isInsideCodeBlock(_ node: Markup) -> Bool {
        var currentNode: Markup? = node
        while let current = currentNode, !(current is Document) {
            if current is CodeBlock || current is InlineCode {
                return true
            }
            currentNode = current.parent
        }
        return false
    }

    func isInsideLink(_ node: Markup) -> Bool {
        var currentNode: Markup? = node
        while let current = currentNode, !(current is Document) {
            if current is Markdown.Link {
                return true
            }
            currentNode = current.parent
        }
        return false
    }
}
