//
//  NSItemProvider.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/12/2.
//

import Foundation

extension NSItemProvider {
    func loadObject<T: NSItemProviderReading>(ofClass: T.Type) async throws -> T? {
        return try await withCheckedThrowingContinuation({ continuation in
            loadObject(ofClass: ofClass) { data, err in
                if let err = err {
                    continuation.resume(throwing: err)
                    return
                }
                
                continuation.resume(returning: data as? T)
            }
        })
    }
}
