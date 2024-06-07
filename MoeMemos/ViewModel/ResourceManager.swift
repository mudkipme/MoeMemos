//
//  ResourceManager.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation

@MainActor
protocol ResourceManager {
    func deleteResource(id: Int) async throws
}
