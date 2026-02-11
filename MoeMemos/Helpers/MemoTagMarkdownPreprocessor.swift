import Foundation
import Markdown

enum MemoTagMarkdownPreprocessor {
    private static let tagLinkScheme = "moememos"
    private static let tagLinkHost = "tag"
    private static let tagNameQueryItem = "name"
    private static let allowedTagCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "/_")
        return set
    }()

    static func preprocessForDisplay(_ markdown: String) -> String {
        let document = Document(parsing: markdown)
        var rewriter = TagLinkDisplayRewriter()
        let rewritten = (rewriter.visit(document) as? Document) ?? document
        return rewritten.format()
    }

    static func restoreRawMarkdown(_ markdown: String) -> String {
        let document = Document(parsing: markdown)
        var rewriter = TagLinkRestoreRewriter()
        let rewritten = (rewriter.visit(document) as? Document) ?? document
        return rewritten.format()
    }

    static func tagName(from url: URL) -> String? {
        guard url.scheme?.lowercased() == tagLinkScheme else {
            return nil
        }
        guard url.host()?.lowercased() == tagLinkHost else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard
            let tagName = components?.queryItems?.first(where: { $0.name == tagNameQueryItem })?.value,
            !tagName.isEmpty
        else {
            return nil
        }

        return tagName
    }

    fileprivate static func tagLinkDestination(for tagName: String) -> String {
        var components = URLComponents()
        components.scheme = tagLinkScheme
        components.host = tagLinkHost
        components.queryItems = [
            URLQueryItem(name: tagNameQueryItem, value: tagName),
        ]
        if let destination = components.string {
            return destination
        }
        return "\(tagLinkScheme)://\(tagLinkHost)?\(tagNameQueryItem)=\(tagName)"
    }

    fileprivate static func tagName(from destination: String?) -> String? {
        guard let destination, let url = URL(string: destination) else {
            return nil
        }
        return tagName(from: url)
    }

    fileprivate static func tagSegments(in text: String) -> [TagSegment] {
        guard !text.isEmpty else {
            return [.text("")]
        }

        var segments: [TagSegment] = []
        var currentTextStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "#" else {
                index = text.index(after: index)
                continue
            }

            let tagStart = text.index(after: index)
            var tagEnd = tagStart
            while tagEnd < text.endIndex && isAllowedTagCharacter(text[tagEnd]) {
                tagEnd = text.index(after: tagEnd)
            }

            guard tagEnd > tagStart else {
                index = text.index(after: index)
                continue
            }

            if currentTextStart < index {
                segments.append(.text(String(text[currentTextStart ..< index])))
            }

            let tag = String(text[tagStart ..< tagEnd])
            segments.append(.tag(tag))

            currentTextStart = tagEnd
            index = tagEnd
        }

        if currentTextStart < text.endIndex {
            segments.append(.text(String(text[currentTextStart ..< text.endIndex])))
        }

        if segments.isEmpty {
            return [.text(text)]
        }
        return segments
    }

    private static func isAllowedTagCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { allowedTagCharacters.contains($0) }
    }
}

private enum TagSegment {
    case text(String)
    case tag(String)
}

private struct TagLinkDisplayRewriter: MarkupRewriter {
    mutating func visitDocument(_ document: Document) -> Markup? {
        let rewrittenChildren = rewriteChildren(Array(document.children))
        return document.withUncheckedChildren(rewrittenChildren)
    }

    private mutating func rewriteChildren(_ children: [Markup]) -> [Markup] {
        var rewrittenChildren: [Markup] = []
        for child in children {
            rewrittenChildren.append(contentsOf: rewriteMarkup(child))
        }
        return rewrittenChildren
    }

    private mutating func rewriteMarkup(_ markup: Markup) -> [Markup] {
        if let text = markup as? Text {
            return rewriteText(text.string)
        }

        if markup is Link || markup is InlineCode || markup is CodeBlock || markup is InlineHTML || markup is HTMLBlock || markup is Image {
            return [markup]
        }

        guard markup.childCount > 0 else {
            return [markup]
        }

        let rewrittenChildren = rewriteChildren(Array(markup.children))
        return [markup.withUncheckedChildren(rewrittenChildren)]
    }

    private func rewriteText(_ text: String) -> [Markup] {
        let segments = MemoTagMarkdownPreprocessor.tagSegments(in: text)
        guard segments.contains(where: {
            if case .tag = $0 {
                return true
            }
            return false
        }) else {
            return [Text(text)]
        }

        var rewritten: [Markup] = []
        for segment in segments {
            switch segment {
            case .text(let plainText):
                if !plainText.isEmpty {
                    rewritten.append(Text(plainText))
                }
            case .tag(let tagName):
                let destination = MemoTagMarkdownPreprocessor.tagLinkDestination(for: tagName)
                rewritten.append(Link(destination: destination, Text("#\(tagName)")))
            }
        }
        return rewritten
    }
}

private struct TagLinkRestoreRewriter: MarkupRewriter {
    mutating func visitDocument(_ document: Document) -> Markup? {
        let rewrittenChildren = rewriteChildren(Array(document.children))
        return document.withUncheckedChildren(rewrittenChildren)
    }

    private mutating func rewriteChildren(_ children: [Markup]) -> [Markup] {
        var rewrittenChildren: [Markup] = []
        for child in children {
            rewrittenChildren.append(contentsOf: rewriteMarkup(child))
        }
        return rewrittenChildren
    }

    private mutating func rewriteMarkup(_ markup: Markup) -> [Markup] {
        if let link = markup as? Link, let tagName = MemoTagMarkdownPreprocessor.tagName(from: link.destination) {
            return [Text("#\(tagName)")]
        }

        if markup is InlineCode || markup is CodeBlock || markup is InlineHTML || markup is HTMLBlock {
            return [markup]
        }

        guard markup.childCount > 0 else {
            return [markup]
        }

        let rewrittenChildren = rewriteChildren(Array(markup.children))
        return [markup.withUncheckedChildren(rewrittenChildren)]
    }
}
