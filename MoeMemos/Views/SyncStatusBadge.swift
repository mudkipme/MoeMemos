import SwiftUI

struct SyncStatusBadge: View {
    let syncing: Bool
    let unsyncedCount: Int
    var hasAuthError: Bool = false
    let syncAction: () -> Void

    var body: some View {
        if syncing {
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel(Text("sync.in-progress"))
            }
        } else {
            Button(action: syncAction) {
                if hasAuthError {
                    Image(systemName: "exclamationmark.icloud")
                        .foregroundStyle(.red)
                } else if unsyncedCount > 0 {
                    Image(systemName: "icloud.slash")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .accessibilityLabel(Text("sync.action"))
        }
    }
}
