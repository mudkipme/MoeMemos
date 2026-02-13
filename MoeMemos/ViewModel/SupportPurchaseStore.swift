//
//  SupportPurchaseStore.swift
//  MoeMemos
//
//  Created by Codex on 2026/2/13.
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class SupportPurchaseStore {
    static let productID = "me.mudkip.MoeMemos.support.one_time"

    var product: Product?
    var hasPurchased = false
    var isLoading = false
    var isPurchasing = false
    var isRestoring = false
    var errorMessage: String?

    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var prepareTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(update)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
        prepareTask?.cancel()
    }

    func prepareIfNeeded() {
        guard prepareTask == nil else { return }
        prepareTask = Task { [weak self] in
            guard let self else { return }
            defer { prepareTask = nil }
            await prepare()
        }
    }

    private func prepare() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let refreshTask: Void = refreshPurchaseStatus()
        async let productTask: Product? = fetchProductSilently()
        product = await productTask
        _ = await refreshTask
    }

    func purchase() async {
        if product == nil {
            product = await fetchProductSilently()
        }

        guard let resolvedProduct = product else {
            errorMessage = NSLocalizedString("settings.support.error.unavailable", comment: "")
            return
        }
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await resolvedProduct.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshPurchaseStatus()
                case .unverified:
                    errorMessage = NSLocalizedString("settings.support.error.unverified", comment: "")
                }
            case .pending:
                errorMessage = NSLocalizedString("settings.support.error.pending", comment: "")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
            if product == nil {
                product = await fetchProductSilently()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPurchaseStatus() async {
        var isPurchased = false
        for await verification in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            guard transaction.revocationDate == nil else { continue }
            if transaction.productID == Self.productID {
                isPurchased = true
                break
            }
        }
        hasPurchased = isPurchased
    }

    private func handleTransactionUpdate(_ verification: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        if transaction.productID == Self.productID, transaction.revocationDate == nil {
            hasPurchased = true
        }
        await transaction.finish()
    }

    private func fetchProductSilently() async -> Product? {
        do {
            return try await Product.products(for: [Self.productID]).first
        } catch {
            return nil
        }
    }
}
