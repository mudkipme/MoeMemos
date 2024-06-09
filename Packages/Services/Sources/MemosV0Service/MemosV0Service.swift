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
import ServiceUtils

@MainActor
public final class MemosV0Service: RemoteService {
    public let hostURL: URL
    let urlSession: URLSession
    let client: Client
    let boundary = UUID().uuidString
    let accessToken: String?

    public nonisolated init(hostURL: URL, accessToken: String?) {
        self.hostURL = hostURL
        self.accessToken = accessToken
        urlSession = URLSession(configuration: URLSessionConfiguration.default)
        client = Client(
            serverURL: hostURL,
            transport: URLSessionTransport(configuration: .init(session: urlSession)),
            middlewares: [
                AccessTokenAuthenticationMiddleware(accessToken: accessToken)
            ]
        )
    }
    
    public func memoVisibilities() -> [MemoVisibility] {
        return [.private, .local, .public]
    }
    
    public func listMemos() async throws -> [Memo] {
        let resp = try await client.listMemos(query: .init(rowStatus: .NORMAL))
        let memos = try resp.ok.body.json
        return memos.map { $0.toMemo(host: hostURL) }
    }
    
    public func listArchivedMemos() async throws -> [Memo] {
        let resp = try await client.listMemos(query: .init(rowStatus: .ARCHIVED))
        let memos = try resp.ok.body.json
        return memos.map { $0.toMemo(host: hostURL) }
    }
    
    public func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?) {
        var offset = 0
        if let pageToken = pageToken, let pageTokenNumber = Int(pageToken) {
            offset = pageTokenNumber
        }
        let resp = try await client.listPublicMemos(query: .init(limit: pageSize, offset: offset))
        let memos = try resp.ok.body.json
        return (memos.map { $0.toMemo(host: hostURL) }, String(offset + pageSize))
    }
    
    public func createMemo(content: String, visibility: MemoVisibility?, resources: [Resource], tags: [String]?) async throws -> Memo {
        var memosVisibility: MemosV0Visibility? = nil
        if let visibility = visibility {
            memosVisibility = .init(memoVisibility: visibility)
        }
        let resp = try await client.createMemo(body: .json(.init(
            content: content,
            resourceIdList: resources.compactMap { if let remoteId = $0.remoteId { return Int(remoteId) } else { return nil } },
            visibility: memosVisibility
        )))
        let memo = try resp.ok.body.json
        
        if let tags = tags {
            for tag in tags {
                _ = try? await client.createTag(body: .json(.init(name: tag)))
            }
        }
        return memo.toMemo(host: hostURL)
    }
    
    public func updateMemo(remoteId: String, content: String?, resources: [Resource]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> Memo {
        guard let id = Int(remoteId) else { throw MoeMemosError.invalidParams }
        var memo: MemosV0Memo?
        if let pinned = pinned {
            let resp = try await client.organizeMemo(path: .init(memoId: id), body: .json(.init(pinned: pinned)))
            memo = try resp.ok.body.json
            // the response might be incorrect
            memo?.pinned = pinned
        }
        
        if let content = content {
            var memosVisibility: MemosV0Visibility? = nil
            if let visibility = visibility {
                memosVisibility = .init(memoVisibility: visibility)
            }
            let resp = try await client.updateMemo(path: .init(memoId: id), body: .json(.init(
                content: content,
                resourceIdList: resources?.compactMap { if let remoteId = $0.remoteId { return Int(remoteId) } else { return nil } },
                visibility: memosVisibility
            )))
            memo = try resp.ok.body.json
        }
        
        if let tags = tags {
            for tag in tags {
                _ = try? await client.createTag(body: .json(.init(name: tag)))
            }
        }
        
        guard let memo = memo else { throw MoeMemosError.invalidParams }
        return memo.toMemo(host: hostURL)
    }
    
    public func deleteMemo(remoteId: String) async throws {
        guard let id = Int(remoteId) else { throw MoeMemosError.invalidParams }
        let resp = try await client.deleteMemo(path: .init(memoId: id))
        _ = try resp.ok
    }
    
    public func archiveMemo(remoteId: String) async throws {
        guard let id = Int(remoteId) else { throw MoeMemosError.invalidParams }
        let resp = try await client.updateMemo(path: .init(memoId: id), body: .json(.init(
            rowStatus: .ARCHIVED
        )))
        _ = try resp.ok
    }
    
    public func restoreMemo(remoteId: String) async throws {
        guard let id = Int(remoteId) else { throw MoeMemosError.invalidParams }
        let resp = try await client.updateMemo(path: .init(memoId: id), body: .json(.init(
            rowStatus: .ARCHIVED
        )))
        _ = try resp.ok
    }
    
    public func listTags() async throws -> [Tag] {
        let resp = try await client.listTags()
        let tags = try resp.ok.body.json
        return tags.map { Tag(name: $0) }
    }
    
    public func deleteTag(name: String) async throws {
        let resp = try await client.deleteTag(body: .json(.init(name: name)))
        _ = try resp.ok
    }
    
    public func listResources() async throws -> [Resource] {
        let resp = try await client.listResources()
        let resources = try resp.ok.body.json
        return resources.map { $0.toResource(host: hostURL) }
    }
    
    public func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource {
        let multipartBody: MultipartBody<Operations.uploadResource.Input.Body.multipartFormPayload> = [
            .undocumented(.init(name: "file", filename: filename, headerFields: [.contentType: type], body: .init(data)))
        ]
        let resp = try await client.uploadResource(body: .multipartForm(multipartBody))
        let resource = try resp.ok.body.json
        return resource.toResource(host: hostURL)
    }
    
    public func deleteResource(remoteId: String) async throws {
        guard let id = Int(remoteId) else { throw MoeMemosError.invalidParams }
        let resp = try await client.deleteResource(path: .init(resourceId: id))
        _ = try resp.ok
    }
    
    public func getCurrentUser() async throws -> Models.User {
        let resp = try await client.getCurrentUser()
        let memosUser = try resp.ok.body.json
        return try await toUser(memosUser)
    }
    
    public func logout() async throws {
        let resp = try await client.signOut()
        _ = try resp.ok.body.json
    }
    
    public func signIn(username: String, password: String) async throws -> (MemosV0User, String?) {
        let resp = try await client.signIn(body: .json(.init(password: password, username: username, remember: true)))
        let user = try resp.ok.body.json
        
        let cookieStorage = urlSession.configuration.httpCookieStorage ?? .shared
        let accessToken = cookieStorage.cookies(for: self.hostURL)?.first(where: { $0.name == "memos.access-token" })?.value
        return (user, accessToken)
    }
    
    public func getStatus() async throws -> Components.Schemas.SystemStatus {
        let resp = try await client.getStatus()
        return try resp.ok.body.json
    }
    
    public func download(url: URL, mimeType: String? = nil) async throws -> URL {
        return try await ServiceUtils.download(urlSession: urlSession, url: url, mimeType: mimeType, middleware: rawAccessTokenMiddlware(hostURL: hostURL, accessToken: accessToken))
    }
    
    func downloadData(url: URL) async throws -> Data {
        return try await ServiceUtils.downloadData(urlSession: urlSession, url: url, middleware: rawAccessTokenMiddlware(hostURL: hostURL, accessToken: accessToken))
    }
    
    func toUser(_ memosUser: MemosV0User) async throws -> User {
        let key = "memos:\(hostURL.absoluteString):\(memosUser.id)"
        let createdAt: Date
        if let createdTs = memosUser.createdTs {
            createdAt = Date(timeIntervalSince1970: TimeInterval(createdTs))
        } else {
            createdAt = .now
        }
        let user = User(accountKey: key, nickname: memosUser.nickname ?? memosUser.username ?? "", defaultVisibility: memosUser.defaultMemoVisibility.toMemoVisibility(), creationDate: createdAt)
        if let avatarUrl = memosUser.avatarUrl, let url = URL(string: avatarUrl) {
            user.avatarData = try? await downloadData(url: url)
        }
        return user
    }
}
