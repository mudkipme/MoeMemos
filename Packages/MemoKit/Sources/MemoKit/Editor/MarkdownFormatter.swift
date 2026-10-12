import Foundation

/// UTF-16 ranges belong to one exact text snapshot. Conversion alone does not
/// guarantee that their endpoints lie on extended-grapheme-cluster boundaries.
enum EditorTextRange {
    static func characters(_ range: NSRange, in text: String) -> Range<String.Index>? {
        let length = text.utf16.count
        guard range.location >= 0, range.location <= length,
              range.length >= 0, range.length <= length - range.location,
              let converted = Range(range, in: text),
              let lower = String.Index(converted.lowerBound, within: text),
              let upper = String.Index(converted.upperBound, within: text) else { return nil }
        return lower..<upper
    }
}

public enum MarkdownFormat: CaseIterable, Sendable {
    case bold
    case italic
    case strikethrough
    case code
    case heading1
    case heading2
    case heading3
    case bulletList
    case numberedList
    case quote
    case link
    case codeBlock

    var localizationKey: String {
        switch self {
        case .bold: "input.format.bold"
        case .italic: "input.format.italic"
        case .strikethrough: "input.format.strikethrough"
        case .code: "input.format.code"
        case .heading1: "input.format.heading1"
        case .heading2: "input.format.heading2"
        case .heading3: "input.format.heading3"
        case .bulletList: "input.format.bullet-list"
        case .numberedList: "input.format.numbered-list"
        case .quote: "input.format.quote"
        case .link: "input.format.link"
        case .codeBlock: "input.format.code-block"
        }
    }

    var title: String {
        Bundle.main.localizedString(forKey: localizationKey, value: nil, table: nil)
    }

    var systemImage: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .strikethrough: "strikethrough"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .heading1: "textformat.size.larger"
        case .heading2: "textformat.size"
        case .heading3: "textformat.size.smaller"
        case .bulletList: "list.bullet"
        case .numberedList: "list.number"
        case .quote: "text.quote"
        case .link: "link"
        case .codeBlock: "curlybraces"
        }
    }
}

/// A single replacement in UTF-16 offsets, matching `UITextView` / `NSString`.
struct MarkdownEdit: Equatable {
    var range: NSRange
    var replacement: String
    var selection: NSRange

    func isValid(in text: String) -> Bool {
        guard EditorTextRange.characters(range, in: text) != nil else { return false }
        return EditorTextRange.characters(selection, in: applied(to: text)) != nil
    }

    func applied(to text: String) -> String {
        (text as NSString).replacingCharacters(in: range, with: replacement)
    }
}

enum MarkdownFormatter {
    static func edit(for format: MarkdownFormat, in text: String, selection: NSRange) -> MarkdownEdit {
        switch format {
        case .bold: return toggleInline("**", in: text, selection: selection)
        case .italic: return toggleInline("_", in: text, selection: selection)
        case .strikethrough: return toggleInline("~~", in: text, selection: selection)
        case .code: return toggleInline("`", in: text, selection: selection)
        case .heading1: return toggleHeading(level: 1, in: text, selection: selection)
        case .heading2: return toggleHeading(level: 2, in: text, selection: selection)
        case .heading3: return toggleHeading(level: 3, in: text, selection: selection)
        case .bulletList: return toggleBulletList(in: text, selection: selection)
        case .numberedList: return toggleNumberedList(in: text, selection: selection)
        case .quote: return toggleQuote(in: text, selection: selection)
        case .link: return insertLink(in: text, selection: selection)
        case .codeBlock: return insertCodeBlock(in: text, selection: selection)
        }
    }

    // MARK: - Inline

    static func toggleInline(_ marker: String, in text: String, selection: NSRange) -> MarkdownEdit {
        let ns = text as NSString
        let selection = trimmingWhitespace(selection, in: ns)
        let markerLength = (marker as NSString).length
        let selected = ns.substring(with: selection)

        // The selection itself includes the markers: `**bold**` -> `bold`.
        if selection.length >= markerLength * 2, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = (selected as NSString).substring(with: NSRange(location: markerLength, length: selection.length - markerLength * 2))
            return MarkdownEdit(
                range: selection,
                replacement: inner,
                selection: NSRange(location: selection.location, length: (inner as NSString).length)
            )
        }

        // The markers surround the selection: **|bold|** -> bold.
        if selection.location >= markerLength, NSMaxRange(selection) + markerLength <= ns.length,
           ns.substring(with: NSRange(location: selection.location - markerLength, length: markerLength)) == marker,
           ns.substring(with: NSRange(location: NSMaxRange(selection), length: markerLength)) == marker {
            return MarkdownEdit(
                range: NSRange(location: selection.location - markerLength, length: selection.length + markerLength * 2),
                replacement: selected,
                selection: NSRange(location: selection.location - markerLength, length: selection.length)
            )
        }

        return MarkdownEdit(
            range: selection,
            replacement: marker + selected + marker,
            selection: NSRange(location: selection.location + markerLength, length: selection.length)
        )
    }

    static func insertLink(in text: String, selection: NSRange) -> MarkdownEdit {
        let ns = text as NSString
        let selection = trimmingWhitespace(selection, in: ns)
        let selected = ns.substring(with: selection)
        if selected.isEmpty {
            let replacement = "[text](url)"
            return MarkdownEdit(range: selection, replacement: replacement, selection: NSRange(location: selection.location + 1, length: 4))
        }
        let replacement = "[\(selected)](url)"
        let urlLocation = selection.location + (replacement as NSString).length - 4
        return MarkdownEdit(range: selection, replacement: replacement, selection: NSRange(location: urlLocation, length: 3))
    }

    static func insertCodeBlock(in text: String, selection: NSRange) -> MarkdownEdit {
        let ns = text as NSString
        let selected = ns.substring(with: selection)
        let atLineStart = selection.location == 0 || ns.substring(with: NSRange(location: selection.location - 1, length: 1)) == "\n"
        let end = NSMaxRange(selection)
        let atLineEnd = end == ns.length || ns.substring(with: NSRange(location: end, length: 1)) == "\n"
        let opening = (atLineStart ? "" : "\n") + "```\n"
        let closing = "\n```" + (atLineEnd ? "" : "\n")
        return MarkdownEdit(
            range: selection,
            replacement: opening + selected + closing,
            selection: NSRange(location: selection.location + (opening as NSString).length, length: selection.length)
        )
    }

    // MARK: - Line prefixes

    private static let headingPattern = try! NSRegularExpression(pattern: "^#{1,6} ")
    private static let bulletPattern = try! NSRegularExpression(pattern: "^[-*+] (\\[[ xX]\\] )?")
    private static let plainBulletPattern = try! NSRegularExpression(pattern: "^[-*+] (?!\\[[ xX]\\] )")
    private static let numberedPattern = try! NSRegularExpression(pattern: "^\\d+[.)] ")
    private static let quotePattern = try! NSRegularExpression(pattern: "^> ?")

    static func toggleHeading(level: Int, in text: String, selection: NSRange) -> MarkdownEdit {
        let prefix = String(repeating: "#", count: level) + " "
        let isApplied: (String) -> Bool = { $0.hasPrefix(prefix) }
        return transformLines(in: text, selection: selection, isApplied: isApplied) { line, applied, _ in
            let existing = prefixLength(headingPattern, in: line)
            return (existing, applied ? "" : prefix)
        }
    }

    static func toggleBulletList(in text: String, selection: NSRange) -> MarkdownEdit {
        transformLines(in: text, selection: selection, isApplied: { prefixLength(plainBulletPattern, in: $0) > 0 }) { line, applied, _ in
            let existing = max(prefixLength(bulletPattern, in: line), prefixLength(numberedPattern, in: line))
            return (existing, applied ? "" : "- ")
        }
    }

    static func toggleNumberedList(in text: String, selection: NSRange) -> MarkdownEdit {
        transformLines(in: text, selection: selection, isApplied: { prefixLength(numberedPattern, in: $0) > 0 }) { line, applied, index in
            let existing = max(prefixLength(bulletPattern, in: line), prefixLength(numberedPattern, in: line))
            return (existing, applied ? "" : "\(index + 1). ")
        }
    }

    static func toggleQuote(in text: String, selection: NSRange) -> MarkdownEdit {
        transformLines(in: text, selection: selection, isApplied: { $0.hasPrefix(">") }) { line, applied, _ in
            applied ? (prefixLength(quotePattern, in: line), "") : (0, "> ")
        }
    }

    /// Cycles the line at the start of the selection through `- [ ] ` and `- [x] `.
    static func toggleTodo(in text: String, selection: NSRange) -> MarkdownEdit {
        let ns = text as NSString
        let lineRange = contentLineRange(of: NSRange(location: selection.location, length: 0), in: ns)
        let fullLine = ns.substring(with: lineRange)
        let indentation = String(fullLine.prefix { $0 == " " || $0 == "\t" })
        let line = String(fullLine.dropFirst(indentation.count))
        let bulletLength = prefixLength(bulletPattern, in: line)
        let existing = max(bulletLength, prefixLength(numberedPattern, in: line))
        let bullet = bulletLength > 0 ? String(line.prefix(1)) : "-"
        let newPrefix = bullet + (line.hasPrefix(bullet + " [ ] ") ? " [x] " : " [ ] ")
        let prefixStart = lineRange.location + indentation.utf16.count
        let edit = LineEdit(lineStart: prefixStart, removedLength: existing, inserted: newPrefix)
        return MarkdownEdit(
            range: NSRange(location: prefixStart, length: existing),
            replacement: newPrefix,
            selection: map(selection, through: [edit])
        )
    }

    // MARK: - Helpers

    private struct LineEdit {
        var lineStart: Int
        var removedLength: Int
        var inserted: String
        var delta: Int { (inserted as NSString).length - removedLength }
    }

    /// Replaces a prefix on every line touched by the selection. Blank lines are skipped
    /// when more than one line is selected. `isApplied` is checked against all
    /// non-blank lines to decide between adding and removing the format.
    private static func transformLines(
        in text: String,
        selection: NSRange,
        isApplied: (String) -> Bool,
        transform: (_ line: String, _ applied: Bool, _ index: Int) -> (removedLength: Int, inserted: String)
    ) -> MarkdownEdit {
        let ns = text as NSString
        let blockRange = contentLineRange(of: selection, in: ns)
        let lines = ns.substring(with: blockRange).components(separatedBy: "\n")
        let candidates = lines.count > 1 ? lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } : lines
        let applied = !candidates.isEmpty && candidates.allSatisfy { isApplied(String($0.drop { $0 == " " || $0 == "\t" })) }

        var edits: [LineEdit] = []
        var output: [String] = []
        var location = blockRange.location
        var index = 0
        for line in lines {
            let length = (line as NSString).length
            if lines.count > 1, line.trimmingCharacters(in: .whitespaces).isEmpty {
                output.append(line)
            } else {
                let indentation = String(line.prefix { $0 == " " || $0 == "\t" })
                let content = String(line.dropFirst(indentation.count))
                let (removed, inserted) = transform(content, applied, index)
                index += 1
                edits.append(LineEdit(lineStart: location + indentation.utf16.count, removedLength: removed, inserted: inserted))
                output.append(indentation + inserted + (content as NSString).substring(from: removed))
            }
            location += length + 1
        }

        return MarkdownEdit(
            range: blockRange,
            replacement: output.joined(separator: "\n"),
            selection: map(selection, through: edits)
        )
    }

    /// The range of the full lines touched by `selection`, without the trailing newline.
    private static func contentLineRange(of selection: NSRange, in ns: NSString) -> NSRange {
        var selection = selection
        // A selection ending right after a newline does not include the next line.
        if selection.length > 0, ns.substring(with: NSRange(location: NSMaxRange(selection) - 1, length: 1)) == "\n" {
            selection.length -= 1
        }
        var range = ns.lineRange(for: selection)
        if range.length > 0, ns.substring(with: NSRange(location: NSMaxRange(range) - 1, length: 1)) == "\n" {
            range.length -= 1
        }
        return range
    }

    private static func map(_ selection: NSRange, through edits: [LineEdit]) -> NSRange {
        func map(_ position: Int) -> Int {
            var shift = 0
            for edit in edits {
                if position < edit.lineStart { break }
                if position < edit.lineStart + edit.removedLength {
                    return edit.lineStart + shift + (edit.inserted as NSString).length
                }
                shift += edit.delta
            }
            return position + shift
        }
        let start = map(selection.location)
        let end = map(NSMaxRange(selection))
        return NSRange(location: start, length: max(0, end - start))
    }

    private static func prefixLength(_ pattern: NSRegularExpression, in line: String) -> Int {
        pattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))?.range.length ?? 0
    }

    private static func trimmingWhitespace(_ selection: NSRange, in ns: NSString) -> NSRange {
        let text = ns as String
        guard let range = EditorTextRange.characters(selection, in: text) else { return selection }
        var start = range.lowerBound
        var end = range.upperBound
        while start < end, text[start].isWhitespace { start = text.index(after: start) }
        while end > start, text[text.index(before: end)].isWhitespace { end = text.index(before: end) }
        return NSRange(start..<end, in: text)
    }
}
