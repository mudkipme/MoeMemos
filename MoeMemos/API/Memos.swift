//
//  Memos.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/6.
//

import Foundation
import CryptoKit
import Models

private let cookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: AppInfo.groupContainerIdentifier)

private let urlSessionConfiguration = {
    let configuration = URLSessionConfiguration.default
    configuration.httpCookieStorage = cookieStorage
    return configuration
}()

class Memos {
    let host: URL
    let accessToken: String?
    let session: URLSession
    private(set) var status: MemosServerStatus? = nil
    
    private init(host: URL, accessToken: String?, openId: String?) {
        self.host = host
        self.accessToken = accessToken?.isEmpty ?? true ? nil : accessToken
        session = URLSession(configuration: urlSessionConfiguration)
        
        // No longer uses cookie when logged-in with Open API
        if let openId = openId, !openId.isEmpty {
            session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
        }
    }
    
    static func create(host: URL, accessToken: String?, openId: String?) async throws -> Memos {
        let memos = Memos(host: host, accessToken: accessToken, openId: openId)
        try await memos.loadStatus()
        return memos
    }
    
    
    func url(for resource: Resource) -> URL {
        if let externalLink = resource.externalLink?.encodeUrlPath(), let url = URL(string: externalLink) {
            return url
        }
        
        var url = host.appendingPathComponent(resource.path())
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "extension", value: URL(fileURLWithPath: resource.filename).pathExtension))
        components.queryItems = queryItems
        url = components.url!
        return url
    }
    
    func download(url: URL) async throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppInfo.groupContainerIdentifier) else { throw MemosError.unknown }
        
        let hash = SHA256.hash(data: url.absoluteString.data(using: .utf8)!)
        let hex = hash.map { String(format: "%02X", $0) }[0...10].joined()
        
        let pathExtension = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "extension" }?.value
        let downloadDestination = containerURL.appendingPathComponent("Library/Caches")
            .appendingPathComponent(hex).appendingPathExtension(pathExtension ?? url.pathExtension)
        
        try FileManager.default.createDirectory(at: downloadDestination.deletingLastPathComponent(), withIntermediateDirectories: true)

        do {
            if try downloadDestination.checkResourceIsReachable() {
                return downloadDestination
            }
        } catch {}
        
        var request = URLRequest(url: url)
        if let accessToken = accessToken, !accessToken.isEmpty && url.host == host.host {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (tmpURL, response) = try await session.download(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw MemosError.unknown
        }
        if response.statusCode < 200 || response.statusCode >= 300 {
            throw MemosError.invalidStatusCode(response.statusCode, url.absoluteString)
        }
        
        try FileManager.default.moveItem(at: tmpURL, to: downloadDestination)
        return downloadDestination
    }
}

fileprivate extension String {
    // encode url path
    func encodeUrlPath() -> String {
        guard self.hasPrefix("http") else { return self}
        guard let index = self.lastIndex(of: "/") else { return self }
        
        let pos = self.index(after: index);
        guard pos != self.endIndex else { return self }
        
        let substring = self.suffix(from: pos)
        if let result = substring.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            return self.replacingCharacters(in: pos..., with: result)
        }
        
        return self
    }
}
