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

public typealias MemosUser = Components.Schemas.User
public typealias MemosMemo = Components.Schemas.Memo
public typealias MemosResource = Components.Schemas.Resource

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

public class MemosService {
    let hostURL: URL
    let urlSession: URLSession
    let client: Client
    let boundary = UUID().uuidString

    init(hostURL: URL, accessToken: String?) {
        self.hostURL = hostURL
        urlSession = URLSession(configuration: URLSessionConfiguration.default)
        client = Client(
            serverURL: hostURL,
            transport: URLSessionTransport(configuration: .init(session: urlSession)),
            middlewares: [
                MemosAuthenticationMiddleware(accessToken: accessToken),
                FormDataMiddleware(boundary: boundary)
            ]
        )
    }
    
    func signIn(username: String, password: String) async throws -> (MemosUser, String?) {
        let resp = try await client.signIn(body: .json(.init(password: password, username: username, remember: true)))
        let user = try resp.ok.body.json
        
        let cookieStorage = urlSession.configuration.httpCookieStorage ?? .shared
        let accessToken = cookieStorage.cookies(for: self.hostURL)?.first(where: { $0.name == "memos.access-token" })?.value
        return (user, accessToken)
    }
    
    func getCurrentUser() async throws -> MemosUser {
        let resp = try await client.getCurrentUser()
        return try resp.ok.body.json
    }
    
    func signOut() async throws {
        let resp = try await client.signOut()
        _ = try resp.ok.body.json
    }
    
    func listMemos(input: Operations.listMemos.Input.Query) async throws -> [MemosMemo] {
        let resp = try await client.listMemos(query: input)
        return try resp.ok.body.json
    }
    
    func listTags() async throws -> [String] {
        let resp = try await client.listTags()
        return try resp.ok.body.json
    }
    
    func createMemo(input: Components.Schemas.CreateMemoRequest) async throws -> MemosMemo {
        let resp = try await client.createMemo(body: .json(input))
        return try resp.ok.body.json
    }
    
    func memoOrganizer(id: Int, pinned: Bool) async throws -> MemosMemo {
        let resp = try await client.organizeMemo(path: .init(memoId: id), body: .json(.init(pinned: pinned)))
        return try resp.ok.body.json
    }
    
    func updateMemo(id: Int, input: Components.Schemas.PatchMemoRequest) async throws -> MemosMemo {
        let resp = try await client.updateMemo(path: .init(memoId: id), body: .json(input))
        return try resp.ok.body.json
    }
    
    func deleteMemo(id: Int) async throws {
        let resp = try await client.deleteMemo(path: .init(memoId: id))
        _ = try resp.ok.body.json
    }
    
    func listResources() async throws -> [MemosResource] {
        let resp = try await client.listResources()
        return try resp.ok.body.json
    }
    
    func uploadResource(imageData: Data, filename: String, contentType: String) async throws -> MemosResource {
        let data = encodeFormData(multiparts: [Multipart(name: "file", filename: filename, contentType: contentType, data: imageData)], boundary: boundary)
        let resp = try await client.uploadResource(body: .multipartForm(.init(data)))
        return try resp.ok.body.json
    }
    
    func deleteResource(id: Int) async throws {
        let resp = try await client.deleteResource(path: .init(resourceId: id))
        _ = try resp.ok.body.json
    }
    
    func getStatus() async throws -> Components.Schemas.SystemStatus {
        let resp = try await client.getStatus()
        return try resp.ok.body.json
    }
    
    func upsertTag(name: String) async throws {
        let resp = try await client.createTag(body: .json(.init(name: name)))
        _ = try resp.ok.body.json
    }
    
    func listPublicMemos(limit: Int, offset: Int) async throws -> [MemosMemo]  {
        let resp = try await client.listPublicMemos(query: .init(limit: limit, offset: offset))
        return try resp.ok.body.json
    }
    
    func deleteTag(name: String) async throws {
        let resp = try await client.deleteTag(body: .json(.init(name: name)))
        _ = try resp.ok.body.json
    }
}
