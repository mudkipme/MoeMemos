import Foundation
import XCTest
@testable import MemoKit

final class MarkdownFormatterTests: XCTestCase {
    /// Applies `format` to `input`, where `[` and `]` mark the selection (or `|` a cursor),
    /// and returns the result in the same notation.
    private func apply(_ format: MarkdownFormat, to input: String) -> String {
        let (text, selection) = parse(input)
        let edit = MarkdownFormatter.edit(for: format, in: text, selection: selection)
        return render(edit.applied(to: text), selection: edit.selection)
    }

    private func applyTodo(to input: String) -> String {
        let (text, selection) = parse(input)
        let edit = MarkdownFormatter.toggleTodo(in: text, selection: selection)
        return render(edit.applied(to: text), selection: edit.selection)
    }

    private func parse(_ input: String) -> (String, NSRange) {
        let ns = input as NSString
        let cursor = ns.range(of: "|")
        if cursor.location != NSNotFound {
            return (ns.replacingCharacters(in: cursor, with: ""), NSRange(location: cursor.location, length: 0))
        }
        let start = ns.range(of: "[").location
        let end = ns.range(of: "]", options: .backwards).location
        let text = input.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        return (text, NSRange(location: start, length: end - start - 1))
    }

    private func render(_ text: String, selection: NSRange) -> String {
        let ns = NSMutableString(string: text)
        if selection.length == 0 {
            ns.insert("|", at: selection.location)
        } else {
            ns.insert("]", at: NSMaxRange(selection))
            ns.insert("[", at: selection.location)
        }
        return ns as String
    }

    func testBoldWrapsSelection() {
        XCTAssertEqual(apply(.bold, to: "say [hello] world"), "say **[hello]** world")
    }

    func testBoldUnwrapsSurroundingMarkers() {
        XCTAssertEqual(apply(.bold, to: "say **[hello]** world"), "say [hello] world")
    }

    func testBoldUnwrapsSelectedMarkers() {
        XCTAssertEqual(apply(.bold, to: "say [**hello**] world"), "say [hello] world")
    }

    func testBoldWithCursorInsertsPairAndRemovesEmptyPair() {
        XCTAssertEqual(apply(.bold, to: "say |"), "say **|**")
        XCTAssertEqual(apply(.bold, to: "say **|**"), "say |")
    }

    func testInlineFormatIgnoresSurroundingWhitespaceInSelection() {
        XCTAssertEqual(apply(.italic, to: "say[ hello ]world"), "say _[hello]_ world")
    }

    func testInlineMarkers() {
        XCTAssertEqual(apply(.strikethrough, to: "[done]"), "~~[done]~~")
        XCTAssertEqual(apply(.code, to: "run [ls]"), "run `[ls]`")
    }

    func testInlineFormatUsesUTF16Offsets() {
        XCTAssertEqual(apply(.bold, to: "🎉 [party] 🎉"), "🎉 **[party]** 🎉")
    }

    func testHeadingAddsReplacesAndRemoves() {
        XCTAssertEqual(apply(.heading1, to: "Ti|tle"), "# Ti|tle")
        XCTAssertEqual(apply(.heading2, to: "# Ti|tle"), "## Ti|tle")
        XCTAssertEqual(apply(.heading2, to: "## Ti|tle"), "Ti|tle")
    }

    func testHeadingOnlyChangesCurrentLine() {
        XCTAssertEqual(apply(.heading1, to: "one\ntw|o\nthree"), "one\n# tw|o\nthree")
    }

    func testBulletListOnEmptyLine() {
        XCTAssertEqual(apply(.bulletList, to: "|"), "- |")
        XCTAssertEqual(apply(.bulletList, to: "intro\n|"), "intro\n- |")
    }

    func testBulletListAppliesToAllSelectedLinesAndSkipsBlankLines() {
        XCTAssertEqual(apply(.bulletList, to: "[a\n\nb]"), "- [a\n\n- b]")
        XCTAssertEqual(apply(.bulletList, to: "- [a\n- b]"), "[a\nb]")
    }

    func testBulletListConvertsNumberedList() {
        XCTAssertEqual(apply(.bulletList, to: "[1. a\n2. b]"), "- [a\n- b]")
    }

    func testNumberedListNumbersLinesAndConvertsBullets() {
        XCTAssertEqual(apply(.numberedList, to: "[a\n- b\nc]"), "1. [a\n2. b\n3. c]")
        XCTAssertEqual(apply(.numberedList, to: "[1. a\n2. b]"), "[a\nb]")
    }

    func testSelectionEndingAtLineStartExcludesNextLine() {
        XCTAssertEqual(apply(.quote, to: "[a\n]b"), "> [a\n]b")
    }

    func testQuoteTogglesPrefix() {
        XCTAssertEqual(apply(.quote, to: "wise| words"), "> wise| words")
        XCTAssertEqual(apply(.quote, to: "> wise| words"), "wise| words")
    }

    func testCursorInsidePrefixMovesAfterNewPrefix() {
        XCTAssertEqual(apply(.heading2, to: "#| Title"), "## |Title")
    }

    // Links use explicit ranges because their brackets clash with the selection notation.
    func testLinkWrapsSelectionAndSelectsURL() {
        let edit = MarkdownFormatter.edit(for: .link, in: "see docs now", selection: NSRange(location: 4, length: 4))
        let result = edit.applied(to: "see docs now")
        XCTAssertEqual(result, "see [docs](url) now")
        XCTAssertEqual((result as NSString).substring(with: edit.selection), "url")
    }

    func testLinkWithCursorSelectsPlaceholderText() {
        let edit = MarkdownFormatter.edit(for: .link, in: "go ", selection: NSRange(location: 3, length: 0))
        let result = edit.applied(to: "go ")
        XCTAssertEqual(result, "go [text](url)")
        XCTAssertEqual((result as NSString).substring(with: edit.selection), "text")
    }

    func testCodeBlockFencesSelectionOnOwnLines() {
        XCTAssertEqual(apply(.codeBlock, to: "[let x = 1]"), "```\n[let x = 1]\n```")
        XCTAssertEqual(apply(.codeBlock, to: "run [ls] now"), "run \n```\n[ls]\n```\n now")
        XCTAssertEqual(apply(.codeBlock, to: "|"), "```\n|\n```")
    }

    func testTodoCyclesCurrentLine() {
        XCTAssertEqual(applyTodo(to: "buy mi|lk"), "- [ ] buy mi|lk")
        XCTAssertEqual(applyTodo(to: "- [ ] buy mi|lk"), "- [x] buy mi|lk")
        XCTAssertEqual(applyTodo(to: "- [x] buy mi|lk"), "- [ ] buy mi|lk")
        XCTAssertEqual(applyTodo(to: "- buy mi|lk"), "- [ ] buy mi|lk")
        XCTAssertEqual(applyTodo(to: "a\nb|"), "a\n- [ ] b|")
    }
}
