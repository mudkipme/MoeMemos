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
        List(viewModel.memoList, id: \.id) { memo in
            Section {
                ExploreMemoCard(memo: memo)
                    .onAppear {
                        Task {
                            if viewModel.memoList.firstIndex(of: memo) == viewModel.memoList.count - 2 {
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

struct Explore_Previews: PreviewProvider {
    static var previews: some View {
        Explore()
    }
}
