import Markdown
import Foundation

struct TagVisitor: MarkupWalker {
    var tags: [String] = []

    private static let allowedTagCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "/_")
        return set
    }()
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        for child in paragraph.inlineChildren {
            if let textNode = child as? Text {
                handleText(textNode)
            }
        }
    }
    
    mutating func handleText(_ text: Text) {
        let content = text.string
        let scanner = Scanner(string: content)
        scanner.charactersToBeSkipped = nil
        while !scanner.isAtEnd {
            _ = scanner.scanUpToString("#")
            guard scanner.scanString("#") != nil else { break }
            
            if let tag = scanner.scanCharacters(from: Self.allowedTagCharacters) {
                tags.append(tag)
            }
        }
    }
}
