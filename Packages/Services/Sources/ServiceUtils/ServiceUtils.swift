//
//  File.swift
//  
//
//  Created by Mudkip on 2024/6/9.
//

import Foundation
import DataURI
import Models
import CryptoKit
import UniformTypeIdentifiers

public func downloadData(urlSession: URLSession, url: URL, middleware: (@Sendable (URLRequest) async throws -> URLRequest)? = nil) async throws -> Data {
    if url.scheme == "data" {
        let (data, _) = try url.absoluteString.dataURIDecoded()
        return data.convertToData()
    }
    
    var request = URLRequest(url: url)
    if let middleware = middleware {
        request = try await middleware(request)
    }
    
    let (data, response) = try await urlSession.data(for: request)
    guard let response = response as? HTTPURLResponse else {
        throw MoeMemosError.unknown
    }
    if response.statusCode < 200 || response.statusCode >= 300 {
        throw MoeMemosError.invalidStatusCode(response.statusCode, url.absoluteString)
    }
    return data
}

public func download(urlSession: URLSession, url: URL, mimeType: String? = nil, middleware: (@Sendable (URLRequest) async throws -> URLRequest)? = nil) async throws -> URL {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppInfo.groupContainerIdentifier) else { throw MoeMemosError.unknown }
    
    let hash = SHA256.hash(data: url.absoluteString.data(using: .utf8)!)
    let hex = hash.map { String(format: "%02X", $0) }[0...10].joined()
    
    var pathExtension = url.pathExtension
    if pathExtension.isEmpty, let mimeType = mimeType, let utType = UTType(mimeType: mimeType), let ext = utType.preferredFilenameExtension {
        pathExtension = ext
    }
    
    let downloadDestination = containerURL.appendingPathComponent("Library/Caches")
        .appendingPathComponent(hex).appendingPathExtension(pathExtension)
    
    try FileManager.default.createDirectory(at: downloadDestination.deletingLastPathComponent(), withIntermediateDirectories: true)

    do {
        if try downloadDestination.checkResourceIsReachable() {
            return downloadDestination
        }
    } catch {}
    
    var request = URLRequest(url: url)
    if let middleware = middleware {
        request = try await middleware(request)
    }
    
    let (tmpURL, response) = try await urlSession.download(for: request)
    guard let response = response as? HTTPURLResponse else {
        throw MoeMemosError.unknown
    }
    if response.statusCode < 200 || response.statusCode >= 300 {
        throw MoeMemosError.invalidStatusCode(response.statusCode, url.absoluteString)
    }
    
    try FileManager.default.moveItem(at: tmpURL, to: downloadDestination)
    return downloadDestination
}
