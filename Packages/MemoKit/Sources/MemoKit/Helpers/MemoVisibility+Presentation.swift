import SwiftUI
import Models

extension MemoVisibility {
    var title: LocalizedStringKey {
        switch self {
        case .public:
            return "memo.visibility.public"
        case .local:
            return "memo.visibility.protected"
        case .private:
            return "memo.visibility.private"
        case .space:
            return "memo.visibility.space"
        case .direct:
            return "memo.visibility.direct"
        case .unlisted:
            return "memo.visibility.unlisted"
        }
    }

    var iconName: String {
        switch self {
        case .public:
            return "globe"
        case .local:
            return "house"
        case .private:
            return "lock"
        case .space:
            return "person.2"
        case .direct:
            return "envelope"
        case .unlisted:
            return "lock.open"
        }
    }
}
