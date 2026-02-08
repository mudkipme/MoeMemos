import SwiftUI

struct SyncStatusBadge: View {
    let syncing: Bool
    let unsyncedCount: Int
    let syncAction: () -> Void

    var body: some View {
        if syncing {
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)
            }
        } else {
            Button(action: syncAction) {
                if unsyncedCount > 0 {
                    Image(systemName: "icloud.slash")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}
