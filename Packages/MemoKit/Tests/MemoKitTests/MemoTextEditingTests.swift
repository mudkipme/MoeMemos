import Foundation
import XCTest
@testable import MemoKit

final class MemoTextEditingTests: XCTestCase {
    private func parse(_ input: String) -> (String, NSRange) {
        let ns = input as NSString
        let cursor = ns.range(of: "|")
        return (ns.replacingCharacters(in: cursor, with: ""), NSRange(location: cursor.location, length: 0))
    }

    private func newline(_ input: String) -> String? {
        let (text, selection) = parse(input)
        guard let edit = MemoTextEditing.newlineEdit(in: text, selection: selection) else { return nil }
        XCTAssertTrue(edit.isValid(in: text))
        let result = NSMutableString(string: edit.applied(to: text))
        result.insert("|", at: edit.selection.location)
        return result as String
    }

    private func tag(_ name: String?, in input: String) -> String {
        let (text, selection) = parse(input)
        let edit = MemoTextEditing.tagEdit(name: name, in: text, selection: selection)
        XCTAssertTrue(edit.isValid(in: text))
        let result = NSMutableString(string: edit.applied(to: text))
        result.insert("|", at: edit.selection.location)
        return result as String
    }

    func testReturnContinuesListsQuotesAndIndentation() {
        XCTAssertEqual(newline("- item|"), "- item\n- |")
        XCTAssertEqual(newline("  + item|"), "  + item\n  + |")
        XCTAssertEqual(newline("\t* item|"), "\t* item\n\t* |")
        XCTAssertEqual(newline("9. item|"), "9. item\n10. |")
        XCTAssertEqual(newline("  9) item|"), "  9) item\n  10) |")
        XCTAssertEqual(newline("> quote|"), "> quote\n> |")
    }

    func testNextChecklistItemStartsUncheckedAndUsesUnicodeOffsets() {
        XCTAssertEqual(newline("🎉\n  - [x] 中文 👨‍👩‍👧‍👦|"), "🎉\n  - [x] 中文 👨‍👩‍👧‍👦\n  - [ ] |")
        XCTAssertEqual(newline("* [X] done|"), "* [X] done\n* [ ] |")
        XCTAssertEqual(newline("+ [ ] todo|"), "+ [ ] todo\n+ [ ] |")
    }

    func testReturnExitsEmptyListsAndQuotes() {
        XCTAssertEqual(newline("- |"), "\n|")
        XCTAssertEqual(newline("intro\n  - [ ] |"), "intro\n\n|")
        XCTAssertEqual(newline("2. |"), "\n|")
        XCTAssertEqual(newline("> |"), "\n|")
        XCTAssertEqual(newline("- |remaining"), "- \n- |remaining")
    }

    func testReturnDoesNotContinueInsideCodeFences() {
        XCTAssertNil(newline("```swift\n- item|\n```"))
        XCTAssertNil(newline("~~~\n1. code|\n~~~"))
        XCTAssertNil(newline("````\n```\n- item|"))
        XCTAssertEqual(newline("```\ncode\n```\n- item|"), "```\ncode\n```\n- item\n- |")
        XCTAssertNil(newline("plain text|"))
        XCTAssertNil(newline("\(Int.max). item|"))
    }

    func testTagCompletionReplacesWholeTokenAndPreservesSurroundingText() {
        XCTAssertEqual(tag("work/project", in: "🎉 #wo|rk notes"), "🎉 #work/project |notes")
        XCTAssertEqual(tag("中文/笔记", in: "#中|"), "#中文/笔记 |")
        XCTAssertEqual(tag("work", in: "(#wo|rk), done"), "(#work|), done")
        XCTAssertEqual(tag("work", in: "#wo|\nnext"), "#work|\nnext")
        XCTAssertEqual(tag("work", in: "word|next"), "word #work |next")
    }

    func testNewTagGetsWordBoundaryAndDoesNotDuplicateLoneHash() {
        XCTAssertEqual(tag(nil, in: "word|"), "word #|")
        XCTAssertEqual(tag(nil, in: "#|"), "#|")
        XCTAssertEqual(tag(nil, in: "#work|"), "#work #|")
    }

    func testTagDetectionSkipsHeadingsAndCodeAndSupportsNestedNames() {
        for input in ["# |Heading", "`#wo|rk`", "``#wo|rk``", "```\n#wo|rk\n```"] {
            let (text, range) = parse(input)
            XCTAssertNil(MemoTextEditing.tagToken(in: text, selection: range), input)
        }
        let (text, range) = parse("中文 #work/pro|ject")
        let token = MemoTextEditing.tagToken(in: text, selection: range)
        XCTAssertEqual(token?.query, "work/pro")
        XCTAssertEqual(token.map { (text as NSString).substring(with: $0.range) }, "#work/project")
    }

    func testTagCompletionPreservesNFCAndNFDSurroundingsAndReplacement() {
        for accent in ["\u{e9}", "e\u{301}"] {
            let (text, selection) = parse("👨‍👩‍👧‍👦 \(accent) #caf\(accent)| notes")
            let token = MemoTextEditing.tagToken(in: text, selection: selection)
            XCTAssertEqual(token.map { Array($0.query.utf16) }, Array("caf\(accent)".utf16))
            let edit = MemoTextEditing.tagEdit(name: "caf\(accent)/work", in: text, selection: selection)
            XCTAssertTrue(edit.isValid(in: text))
            XCTAssertEqual(Array(edit.applied(to: text).utf16), Array("👨‍👩‍👧‍👦 \(accent) #caf\(accent)/work notes".utf16))
        }
    }
}
