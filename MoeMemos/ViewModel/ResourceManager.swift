//
//  ResourceManager.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation

protocol ResourceManager {
    @MainActor
    func deleteResource(id: Int) async throws
}
