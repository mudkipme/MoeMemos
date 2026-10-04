import AppIntents
import Models
import SwiftUI

public extension View {
    /// Associate visible content without changing its rendering on older systems.
    @MainActor @ViewBuilder
    func memoEntity(_ memo: StoredMemo?) -> some View {
        let token = memo.flatMap { memo in
            !memo.softDeleted && memo.rowStatus == .normal
                ? MemoEntityIdentifier(accountKey: memo.accountKey, persistentID: memo.id).token : nil
        }
        if #available(iOS 27, macOS 27, visionOS 27, *) {
            appEntityIdentifier(token.map { EntityIdentifier(for: SiriMemoEntity.self, identifier: $0) })
        } else if #available(iOS 18.4, macOS 15.4, visionOS 2.4, *) {
            appEntityIdentifier(token.map { EntityIdentifier(for: MemoEntity.self, identifier: $0) })
        } else {
            self
        }
    }
}
