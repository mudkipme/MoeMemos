import Foundation

/// Editor transformations use UIKit's UTF-16 ranges and run only for explicit edits.
enum MemoTextEditing {
    struct TagToken: Equatable {
        let range: NSRange
        let query: String
    }

    private static let listPrefix = try! NSRegularExpression(
        pattern: #"^([ \t]*)(?:([-*+]) (\[[ xX]\] )?|(\d+)([.)]) |> ?)(.*)$"#
    )
    private static let fence = try! NSRegularExpression(pattern: #"^ {0,3}(`{3,}|~{3,})(.*)$"#)
    private static let tagCharacters: CharacterSet = {
        var characters = CharacterSet.alphanumerics
        characters.insert(charactersIn: "/_-")
        return characters
    }()

    /// Replaces a Return-key edit, keeping newline and continuation in one undoable edit.
    static func newlineEdit(in text: String, selection: NSRange) -> MarkdownEdit? {
        guard let range = EditorTextRange.characters(selection, in: text) else { return nil }
        let beforeCursor = text[..<range.lowerBound]
        let lineStart = beforeCursor.lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        guard !isInFencedCode(text[..<lineStart]) else { return nil }
        let line = String(text[lineStart..<range.lowerBound])
        let ns = line as NSString
        guard let match = listPrefix.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func capture(_ index: Int) -> String {
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
        let indentation = capture(1)
        let content = capture(6)
        let remainingLine = text[range.upperBound...].prefix { $0 != "\n" }
        if content.trimmingCharacters(in: .whitespaces).isEmpty,
           remainingLine.trimmingCharacters(in: .whitespaces).isEmpty {
            let start = lineStart.utf16Offset(in: text)
            return MarkdownEdit(
                range: NSRange(location: start, length: NSMaxRange(selection) - start),
                replacement: "\n", selection: NSRange(location: start + 1, length: 0)
            )
        }
        let prefix: String
        if !capture(2).isEmpty {
            prefix = indentation + capture(2) + " " + (capture(3).isEmpty ? "" : "[ ] ")
        } else if !capture(4).isEmpty {
            guard let number = Int(capture(4)), number < Int.max else { return nil }
            prefix = indentation + "\(number + 1)" + capture(5) + " "
        } else {
            prefix = indentation + "> "
        }
        let replacement = "\n" + prefix
        return MarkdownEdit(
            range: selection, replacement: replacement,
            selection: NSRange(location: selection.location + replacement.utf16.count, length: 0)
        )
    }

    static func tagToken(in text: String, selection: NSRange) -> TagToken? {
        guard selection.length == 0, let cursor = EditorTextRange.characters(selection, in: text)?.lowerBound,
              !isInFencedCode(text[..<cursor]) else { return nil }
        let scalars = text.unicodeScalars
        var start = cursor
        while start > scalars.startIndex, tagCharacters.contains(scalars[scalars.index(before: start)]) {
            start = scalars.index(before: start)
        }
        guard start > scalars.startIndex else { return nil }
        let hash = scalars.index(before: start)
        guard scalars[hash] == "#" else { return nil }
        // Do not treat an inline-code fragment or Markdown heading as an editable tag.
        let linePrefix = text[..<hash].split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
        var codeMarkerLength: Int?
        let tickRuns = linePrefix.split(whereSeparator: { $0 != "`" })
        for run in tickRuns {
            if codeMarkerLength == run.count { codeMarkerLength = nil }
            else if codeMarkerLength == nil { codeMarkerLength = run.count }
        }
        guard codeMarkerLength == nil else { return nil }
        var end = cursor
        while end < scalars.endIndex, tagCharacters.contains(scalars[end]) {
            end = scalars.index(after: end)
        }
        if start == end, end < text.endIndex, text[end].isWhitespace { return nil }
        let range = NSRange(hash..<end, in: text)
        guard EditorTextRange.characters(range, in: text) != nil else { return nil }
        return TagToken(range: range, query: String(text[start..<cursor]))
    }

    static func tagEdit(name: String?, in text: String, selection: NSRange) -> MarkdownEdit {
        let token = tagToken(in: text, selection: selection)
        var range = (name != nil || token?.query.isEmpty == true) ? token?.range ?? selection : selection
        let ns = text as NSString
        let before = ns.substring(to: range.location)
        let after = ns.substring(from: NSMaxRange(range))
        let leading = before.last.map { $0.isWhitespace || "#([{ ".contains($0) ? "" : " " } ?? ""
        let needsSeparator = after.first.map { !$0.isWhitespace && !$0.isPunctuation } ?? true
        let trailing: String
        if name != nil, let separator = after.first, separator == " " || separator == "\t" {
            // Reuse the existing separator and place the cursor outside the tag.
            range.length += 1
            trailing = String(separator)
        } else {
            trailing = name != nil && needsSeparator ? " " : ""
        }
        let replacement = leading + "#" + (name ?? "") + trailing
        return MarkdownEdit(
            range: range, replacement: replacement,
            selection: NSRange(location: range.location + replacement.utf16.count, length: 0)
        )
    }

    private static func isInFencedCode(_ prefix: Substring) -> Bool {
        var opening: (character: Character, count: Int)?
        for line in prefix.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(line)
            let ns = line as NSString
            guard let match = fence.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { continue }
            let marker = ns.substring(with: match.range(at: 1))
            let suffix = ns.substring(with: match.range(at: 2))
            if let current = opening {
                if marker.first == current.character, marker.count >= current.count,
                   suffix.trimmingCharacters(in: .whitespaces).isEmpty { opening = nil }
            } else if marker.first != "`" || !suffix.contains("`") {
                opening = (marker.first!, marker.count)
            }
        }
        return opening != nil
    }
}
