import Foundation
import Markdown

@MainActor
enum MemoMarkdownPreprocessor {
    private static let markdownCache = NSCache<NSString, CacheEntry>()
    private static let truncationLimit = 500
    private static let unbreakableBlockCost = 100
    private static let viewMoreLinkDestination = "moememos://memo/view-more"

    static func preprocess(_ markdown: String, truncate: Bool) -> (String, Bool) {
        guard truncate else {
            return (markdown, false)
        }

        let key = cacheKey(for: markdown)
        if let cached = markdownCache.object(forKey: key) {
            return (cached.markdown as String, cached.truncated)
        }

        let document = Document(parsing: markdown)
        var rewriter = MemoMarkdownRewriter(
            characterLimit: truncationLimit,
            unbreakableCost: unbreakableBlockCost
        )
        let processedDocument = (rewriter.visit(document) as? Document) ?? document
        var preprocessedMarkdown = processedDocument.format()
        if rewriter.truncated {
            let viewMoreText = NSLocalizedString("memo.view-more", comment: "View more link for truncated memo")
            preprocessedMarkdown += "\n\n[\(viewMoreText)](\(viewMoreLinkDestination))"
        }

        let entry = CacheEntry(markdown: preprocessedMarkdown as NSString, truncated: rewriter.truncated)
        markdownCache.setObject(entry, forKey: key)
        return (preprocessedMarkdown, rewriter.truncated)
    }

    private static func cacheKey(for markdown: String) -> NSString {
        markdown as NSString
    }
}

private final class CacheEntry: NSObject {
    let markdown: NSString
    let truncated: Bool

    init(markdown: NSString, truncated: Bool) {
        self.markdown = markdown
        self.truncated = truncated
    }
}

private struct MemoMarkdownRewriter: MarkupRewriter {
    let characterLimit: Int
    let unbreakableCost: Int
    private(set) var truncated = false
    private var remainingCharacters: Int

    init(characterLimit: Int, unbreakableCost: Int) {
        self.characterLimit = characterLimit
        self.unbreakableCost = unbreakableCost
        self.remainingCharacters = characterLimit
    }

    mutating func visitDocument(_ document: Document) -> Markup? {
        var rewrittenChildren = rewriteBlockChildren(Array(document.children))
        if truncated {
            appendEllipsis(to: &rewrittenChildren)
        }
        return document.withUncheckedChildren(rewrittenChildren)
    }

    private mutating func rewriteBlockChildren(_ blocks: [Markup]) -> [Markup] {
        var rewrittenBlocks: [Markup] = []

        for block in blocks {
            guard remainingCharacters > 0 else {
                truncated = true
                break
            }

            guard let rewrittenBlock = rewriteBlock(block) else {
                if truncated {
                    break
                }
                continue
            }

            rewrittenBlocks.append(rewrittenBlock)
        }

        return rewrittenBlocks
    }

    private mutating func rewriteBlock(_ block: Markup) -> Markup? {
        if let paragraph = block as? Paragraph {
            return rewriteParagraph(paragraph)
        }
        if block is ListItem || block is BlockQuote {
            return rewriteBlockContainer(block)
        }
        if block is OrderedList || block is UnorderedList {
            return rewriteListContainer(block)
        }
        return consumeUnbreakableBlock(block)
    }

    private mutating func rewriteListContainer(_ list: Markup) -> Markup? {
        guard list.childCount > 0 else {
            return list
        }

        var rewrittenItems: [Markup] = []
        for item in list.children {
            guard remainingCharacters > 0 else {
                truncated = true
                break
            }

            guard let rewrittenItem = rewriteBlock(item) else {
                if truncated {
                    break
                }
                continue
            }

            rewrittenItems.append(rewrittenItem)
        }

        guard !rewrittenItems.isEmpty else {
            truncated = true
            return nil
        }

        return list.withUncheckedChildren(rewrittenItems)
    }

    private mutating func rewriteBlockContainer(_ container: Markup) -> Markup? {
        guard container.childCount > 0 else {
            return container
        }

        let rewrittenChildren = rewriteBlockChildren(Array(container.children))
        guard !rewrittenChildren.isEmpty else {
            truncated = true
            return nil
        }

        return container.withUncheckedChildren(rewrittenChildren)
    }

    private mutating func rewriteParagraph(_ paragraph: Paragraph) -> Markup? {
        guard paragraph.childCount > 0 else {
            return paragraph
        }

        let rewrittenInlines = rewriteInlineChildren(Array(paragraph.children))
        guard !rewrittenInlines.isEmpty else {
            truncated = true
            return nil
        }

        return paragraph.withUncheckedChildren(rewrittenInlines)
    }

    private mutating func rewriteInlineChildren(_ inlines: [Markup]) -> [Markup] {
        var rewrittenInlines: [Markup] = []

        for inline in inlines {
            guard remainingCharacters > 0 else {
                truncated = true
                break
            }

            guard let rewrittenInline = rewriteInline(inline) else {
                if truncated {
                    break
                }
                continue
            }

            rewrittenInlines.append(rewrittenInline)
        }

        return rewrittenInlines
    }

    private mutating func rewriteInline(_ inline: Markup) -> Markup? {
        if let text = inline as? Text {
            return consumeText(text)
        }
        if let inlineCode = inline as? InlineCode {
            return consumeInlineCode(inlineCode)
        }
        if inline is Image || inline is InlineHTML {
            return consumeUnbreakableInline(inline)
        }
        if inline is LineBreak || inline is SoftBreak {
            return consumeInline(inline, count: 1)
        }
        if inline is InlineAttributes {
            return inline
        }

        if inline.childCount > 0 {
            let rewrittenChildren = rewriteInlineChildren(Array(inline.children))
            guard !rewrittenChildren.isEmpty else {
                truncated = true
                return nil
            }
            return inline.withUncheckedChildren(rewrittenChildren)
        }

        if let plainText = (inline as? PlainTextConvertibleMarkup)?.plainText, !plainText.isEmpty {
            return consumeInline(inline, count: plainText.count)
        }

        return consumeUnbreakableInline(inline)
    }

    private mutating func consumeText(_ text: Text) -> Markup? {
        let textCount = text.string.count
        guard textCount > 0 else {
            return text
        }

        if textCount <= remainingCharacters {
            remainingCharacters -= textCount
            return text
        }

        guard remainingCharacters > 0 else {
            truncated = true
            return nil
        }

        let prefix = String(text.string.prefix(remainingCharacters))
        remainingCharacters = 0
        truncated = true
        return prefix.isEmpty ? nil : Text(prefix)
    }

    private mutating func consumeInlineCode(_ inlineCode: InlineCode) -> Markup? {
        let codeCount = inlineCode.code.count
        guard codeCount > 0 else {
            return inlineCode
        }

        if codeCount <= remainingCharacters {
            remainingCharacters -= codeCount
            return inlineCode
        }

        guard remainingCharacters > 0 else {
            truncated = true
            return nil
        }

        let prefix = String(inlineCode.code.prefix(remainingCharacters))
        remainingCharacters = 0
        truncated = true
        return prefix.isEmpty ? nil : InlineCode(prefix)
    }

    private mutating func consumeInline(_ inline: Markup, count: Int) -> Markup? {
        if count <= remainingCharacters {
            remainingCharacters -= count
            return inline
        }
        truncated = true
        return nil
    }

    private mutating func consumeUnbreakableInline(_ inline: Markup) -> Markup? {
        guard remainingCharacters >= unbreakableCost else {
            truncated = true
            return nil
        }
        remainingCharacters -= unbreakableCost
        return inline
    }

    private mutating func consumeUnbreakableBlock(_ block: Markup) -> Markup? {
        guard remainingCharacters >= unbreakableCost else {
            truncated = true
            return nil
        }
        remainingCharacters -= unbreakableCost
        return block
    }

    private func appendEllipsis(to blocks: inout [Markup]) {
        if appendEllipsisToLastInline(in: &blocks) {
            return
        }
        blocks.append(Paragraph(Text("…")))
    }

    private func appendEllipsisToLastInline(in blocks: inout [Markup]) -> Bool {
        guard !blocks.isEmpty else {
            return false
        }

        for index in stride(from: blocks.count - 1, through: 0, by: -1) {
            let block = blocks[index]

            if block is ListItem || block is BlockQuote || block is OrderedList || block is UnorderedList {
                var children = Array(block.children)
                if appendEllipsisToLastInline(in: &children) {
                    blocks[index] = block.withUncheckedChildren(children)
                    return true
                }
                continue
            }

            guard let paragraph = block as? Paragraph else {
                continue
            }

            var inlines = Array(paragraph.children)
            if appendEllipsisToInlines(&inlines) {
                blocks[index] = paragraph.withUncheckedChildren(inlines)
                return true
            }
        }

        return false
    }

    private func appendEllipsisToInlines(_ inlines: inout [Markup]) -> Bool {
        guard !inlines.isEmpty else {
            return false
        }

        let lastIndex = inlines.endIndex - 1
        let lastInline = inlines[lastIndex]

        if var text = lastInline as? Text {
            text.string += "…"
            inlines[lastIndex] = text
            return true
        }

        if var inlineCode = lastInline as? InlineCode {
            inlineCode.code += "…"
            inlines[lastIndex] = inlineCode
            return true
        }

        if lastInline.childCount > 0 {
            var nestedChildren = Array(lastInline.children)
            if appendEllipsisToInlines(&nestedChildren) {
                inlines[lastIndex] = lastInline.withUncheckedChildren(nestedChildren)
                return true
            }
        }

        inlines.append(Text("…"))
        return true
    }
}
