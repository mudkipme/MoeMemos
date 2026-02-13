//
//  Settings.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import SwiftUI
import Models
import Account

struct Settings: View {
    @Environment(AppInfo.self) var appInfo: AppInfo
    @Environment(AccountViewModel.self) var accountViewModel
    @State private var supportPurchaseStore = SupportPurchaseStore()

    var body: some View {
        @Bindable var accountViewModel = accountViewModel
        List {
            AccountSectionView()

            Section {
                if supportPurchaseStore.hasPurchased {
                    Label("settings.support.thanks", systemImage: "heart.fill")
                        .foregroundStyle(.tint)
                } else {
                    Button {
                        Task {
                            await supportPurchaseStore.purchase()
                        }
                    } label: {
                        HStack {
                            Label("settings.support.buy", systemImage: "cup.and.saucer.fill")
                            Spacer()
                            if supportPurchaseStore.isLoading {
                                ProgressView()
                            } else if let product = supportPurchaseStore.product {
                                Text(product.displayPrice)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(supportPurchaseStore.product == nil || supportPurchaseStore.isPurchasing)

                    if supportPurchaseStore.isPurchasing {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            } header: {
                HStack {
                    Text("settings.support")
                    Spacer()

                    if !supportPurchaseStore.hasPurchased {
                        if supportPurchaseStore.isRestoring {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("settings.support.restore") {
                                Task {
                                    await supportPurchaseStore.restore()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .disabled(supportPurchaseStore.isRestoring)
                        }
                    }
                }
            }
            
            Section {
                Link(destination: appInfo.website) {
                    Label("settings.website", systemImage: "globe")
                }
                Link(destination: appInfo.privacy) {
                    Label("settings.privacy", systemImage: "lock")
                }
                Link(destination: URL(string: "https://memos.moe/ios-acknowledgements")!) {
                    Label("settings.acknowledgements", systemImage: "info.bubble")
                }
                Link(destination: URL(string: "https://github.com/mudkipme/MoeMemos/issues")!) {
                    Label("settings.report", systemImage: "smallcircle.filled.circle")
                }
            } header: {
                Text("settings.about")
            } footer: {
                Text(appInfo.registration)
            }
        }
        .onAppear {
            supportPurchaseStore.prepareIfNeeded()
        }
        .alert(
            "settings.support.error.title",
            isPresented: Binding(
                get: { supportPurchaseStore.errorMessage != nil },
                set: { shouldShow in
                    if !shouldShow {
                        supportPurchaseStore.errorMessage = nil
                    }
                }
            )
        ) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(supportPurchaseStore.errorMessage ?? "")
        }
        .navigationTitle("settings")
    }
}
