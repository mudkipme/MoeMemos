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
import OpenAPIRuntime
import HTTPTypes

private struct ErrorMessagePayload: Decodable {
    let message: String?
}

/// Converts non-2xx HTTP responses into typed `MoeMemosError` values so sync and UI layers
/// can reliably distinguish auth expiry (401/403), missing resources (404), and transient 5xx errors.
public struct HTTPStatusErrorMiddleware: ClientMiddleware {
    public init() {}

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)
        let statusCode = response.status.code
        guard (200..<300).contains(statusCode) else {
            if statusCode == 401 || statusCode == 403 {
                throw MoeMemosError.accessTokenExpired
            }
            var message: String?
            if let responseBody,
               let data = try? await Data(collecting: responseBody, upTo: 65_536),
               let payload = try? JSONDecoder().decode(ErrorMessagePayload.self, from: data),
               let decodedMessage = payload.message,
               !decodedMessage.isEmpty {
                message = decodedMessage
            }
            throw MoeMemosError.invalidStatusCode(statusCode, message)
        }
        return (response, responseBody)
    }
}

/// Unwraps `OpenAPIRuntime.ClientError` to expose the underlying `MoeMemosError` or `URLError`.
public func normalizeClientError<T>(
    isolation: isolated (any Actor)? = #isolation,
    _ operation: () async throws -> T
) async throws -> T {
    do {
        return try await operation()
    } catch let clientError as ClientError {
        if let memosError = clientError.underlyingError as? MoeMemosError {
            throw memosError
        }
        if let urlError = clientError.underlyingError as? URLError {
            throw urlError
        }
        if let statusCode = clientError.response?.status.code {
            if statusCode == 401 || statusCode == 403 {
                throw MoeMemosError.accessTokenExpired
            }
            throw MoeMemosError.invalidStatusCode(statusCode, nil)
        }
        throw clientError
    }
}

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
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStorageConfiguration.groupContainerIdentifier) else { throw MoeMemosError.unknown }
    
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
