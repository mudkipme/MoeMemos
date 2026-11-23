public struct SemanticVersion: Comparable, Sendable {
    private let major: Int
    private let minor: Int
    private let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ raw: String) {
        var components = [Int]()
        var current = ""

        for char in raw {
            if char.isNumber {
                current.append(char)
                continue
            }
            if !current.isEmpty {
                if let value = Int(current) {
                    components.append(value)
                    if components.count == 3 {
                        break
                    }
                }
                current = ""
            }
        }

        if components.count < 3, !current.isEmpty, let value = Int(current) {
            components.append(value)
        }

        guard components.count >= 2 else {
            return nil
        }

        let major = components[0]
        let minor = components[1]
        let patch = components.count >= 3 ? components[2] : 0
        self.init(major: major, minor: minor, patch: patch)
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}
