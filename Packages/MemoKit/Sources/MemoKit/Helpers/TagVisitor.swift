import Markdown

struct TagVisitor: MarkupWalker {
    var tags: [String] = []

    mutating func visitText(_ text: Text) {
        let content = text.string
        let components = content.components(separatedBy: "#")
        for component in components {
            if component.isEmpty {
                continue
            }
            let tag = component.split { $0.isWhitespace || $0 == "#" }.first
            if let tag = tag {
                tags.append(String(tag))
            }
        }
    }
}
