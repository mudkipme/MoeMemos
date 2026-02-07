import Foundation
import Markdown

@MainActor
enum MemoMarkdownPreprocessor {
    private static let markdownCache = NSCache<NSString, NSString>()

    static func preprocess(_ markdown: String) -> String {
        let key = markdown as NSString
        if let cached = markdownCache.object(forKey: key) {
            return cached as String
        }

        let document = Document(parsing: markdown)
        var rewriter = MemoMarkdownRewriter()
        let processedDocument = (rewriter.visit(document) as? Document) ?? document
        let preprocessedMarkdown = processedDocument.format()
        markdownCache.setObject(preprocessedMarkdown as NSString, forKey: key)
        return preprocessedMarkdown
    }
}

private struct MemoMarkdownRewriter: MarkupRewriter {
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> Markup? {
        codeBlock
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> Markup? {
        inlineCode
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> Markup? {
        html
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> Markup? {
        inlineHTML
    }

    mutating func visitLink(_ link: Link) -> Markup? {
        link
    }

    mutating func visitImage(_ image: Image) -> Markup? {
        image
    }

    mutating func visitText(_ text: Text) -> Markup? {
        text
    }
}
