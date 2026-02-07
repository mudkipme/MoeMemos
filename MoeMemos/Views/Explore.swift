//
//  Explore.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import SwiftUI

struct Explore: View {
    @State private var viewModel = ExploreViewModel()

    var body: some View {
        List(viewModel.memoList, id: \.remoteId) { memo in
            Section {
                ExploreMemoCard(memo: memo)
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
