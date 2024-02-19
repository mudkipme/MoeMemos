//
//  MemosService.swift
//
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes
import Models
import CryptoKit

struct MemosAuthenticationMiddleware: ClientMiddleware {
    var accessToken: String?

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        if let accessToken = accessToken {
            request.headerFields[.authorization] = "Bearer \(accessToken)"
        }
        return try await next(request, body, baseURL)
    }
}

public final class MemosService: Sendable {
    public let hostURL: URL
    let urlSession: URLSession
    let client: Client
    let boundary = UUID().uuidString
    let accessToken: String?

    public init(hostURL: URL, accessToken: String?) {
        self.hostURL = hostURL
        self.accessToken = accessToken
        urlSession = URLSession(configuration: URLSessionConfiguration.default)
        client = Client(
            serverURL: hostURL,
            transport: URLSessionTransport(configuration: .init(session: urlSession)),
            middlewares: [
                MemosAuthenticationMiddleware(accessToken: accessToken)
            ]
        )
    }
    
    public func signIn(username: String, password: String) async throws -> (MemosUser, String?) {
        let resp = try await client.signIn(body: .json(.init(password: password, username: username, remember: true)))
        let user = try resp.ok.body.json
        
        let cookieStorage = urlSession.configuration.httpCookieStorage ?? .shared
        let accessToken = cookieStorage.cookies(for: self.hostURL)?.first(where: { $0.name == "memos.access-token" })?.value
        return (user, accessToken)
    }
    
    public func getCurrentUser() async throws -> MemosUser {
        let resp = try await client.getCurrentUser()
        return try resp.ok.body.json
    }
    
    public func signOut() async throws {
        let resp = try await client.signOut()
        _ = try resp.ok.body.json
    }
    
    public func listMemos(input: Operations.listMemos.Input.Query) async throws -> [MemosMemo] {
        let resp = try await client.listMemos(query: input)
        return try resp.ok.body.json
    }
    
    public func listTags() async throws -> [String] {
        let resp = try await client.listTags()
        return try resp.ok.body.json
    }
    
    public func createMemo(input: Components.Schemas.CreateMemoRequest) async throws -> MemosMemo {
        let resp = try await client.createMemo(body: .json(input))
        return try resp.ok.body.json
    }
    
    public func memoOrganizer(id: Int, pinned: Bool) async throws -> MemosMemo {
        let resp = try await client.organizeMemo(path: .init(memoId: id), body: .json(.init(pinned: pinned)))
        return try resp.ok.body.json
    }
    
    public func updateMemo(id: Int, input: Components.Schemas.PatchMemoRequest) async throws -> MemosMemo {
        let resp = try await client.updateMemo(path: .init(memoId: id), body: .json(input))
        return try resp.ok.body.json
    }
    
    public func deleteMemo(id: Int) async throws {
        let resp = try await client.deleteMemo(path: .init(memoId: id))
        _ = try resp.ok.body.json
    }
    
    public func listResources() async throws -> [MemosResource] {
        let resp = try await client.listResources()
        return try resp.ok.body.json
    }
    
    public func uploadResource(imageData: Data, filename: String, contentType: String) async throws -> MemosResource {
        let multipartBody: MultipartBody<Operations.uploadResource.Input.Body.multipartFormPayload> = [
            .file(.init(payload: .init(headers: .init(Content_hyphen_Type: contentType), body: .init(imageData)), filename: filename))
        ]
        let resp = try await client.uploadResource(body: .multipartForm(multipartBody))
        return try resp.ok.body.json
    }
//    
    public func deleteResource(id: Int) async throws {
        let resp = try await client.deleteResource(path: .init(resourceId: id))
        _ = try resp.ok.body.json
    }
    
    public func getStatus() async throws -> Components.Schemas.SystemStatus {
        let resp = try await client.getStatus()
        return try resp.ok.body.json
    }
    
    public func upsertTag(name: String) async throws {
        let resp = try await client.createTag(body: .json(.init(name: name)))
        _ = try resp.ok.body.json
    }
    
    public func listPublicMemos(limit: Int, offset: Int) async throws -> [MemosMemo]  {
        let resp = try await client.listPublicMemos(query: .init(limit: limit, offset: offset))
        return try resp.ok.body.json
    }
    
    public func deleteTag(name: String) async throws {
        let resp = try await client.deleteTag(body: .json(.init(name: name)))
        _ = try resp.ok.body.json
    }
}

fileprivate extension MemosResource {
    func path() -> String {
        return "/o/r/\(id)/\(name)"
    }
}

public extension MemosService {
    func url(for resource: MemosResource) -> URL {
        if let externalLink = resource.externalLink?.encodeUrlPath(), let url = URL(string: externalLink) {
            return url
        }
        
        var url = hostURL.appendingPathComponent(resource.path())
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "extension", value: URL(fileURLWithPath: resource.filename).pathExtension))
        components.queryItems = queryItems
        url = components.url!
        return url
    }
    
    func downloadData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        if let accessToken = accessToken, !accessToken.isEmpty && url.host == hostURL.host {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await urlSession.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw MemosServiceError.unknown
        }
        if response.statusCode < 200 || response.statusCode >= 300 {
            throw MemosServiceError.invalidStatusCode(response.statusCode, url.absoluteString)
        }
        return data
    }
    
    func download(url: URL) async throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppInfo.groupContainerIdentifier) else { throw MemosServiceError.unknown }
        
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
        if let accessToken = accessToken, !accessToken.isEmpty && url.host == hostURL.host {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (tmpURL, response) = try await urlSession.download(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw MemosServiceError.unknown
        }
        if response.statusCode < 200 || response.statusCode >= 300 {
            throw MemosServiceError.invalidStatusCode(response.statusCode, url.absoluteString)
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
