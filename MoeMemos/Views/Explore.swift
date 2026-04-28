//
//  Explore.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI
import Account

struct Explore: View {
    @State private var viewModel = ExploreViewModel()
    @Environment(AccountViewModel.self) private var accountViewModel: AccountViewModel

    var body: some View {
        let isAdmin = accountViewModel.currentUser?.isAdmin ?? false

        Group {
            if viewModel.memoList.isEmpty {
                ContentUnavailableView("explore.empty", systemImage: "globe")
            } else {
                List(viewModel.memoList, id: \.remoteId) { memo in
                    Section {
                        ExploreMemoCard(memo: memo, isAdmin: isAdmin) { remoteId, content, visibility in
                            try await viewModel.editMemo(remoteId: remoteId, content: content, visibility: visibility)
                        }
                        .onAppear {
                            Task {
                                if viewModel.memoList.firstIndex(where: { $0.remoteId == memo.remoteId }) == viewModel.memoList.count - 2 {
                                    try await viewModel.loadMoreMemos()
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("explore")
        .task {
            do {
                try await viewModel.loadMemos()
            } catch {
                print(error)
            }
        }
        .refreshable {
            do {
                try await viewModel.loadMemos()
            } catch {
                print(error)
            }
        }
    }
}
