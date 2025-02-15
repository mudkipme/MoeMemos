//
//  MemosV1Service.swift
//
//
//  Created by Mudkip on 2024/6/9.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes
import Models
import ServiceUtils

@MainActor
public final class MemosV1Service: RemoteService {
    private let hostURL: URL
    private let urlSession: URLSession
    private let client: Client
    private let accessToken: String?
    private let userId: String?
    private let grpcSetCookieMiddleware = GRPCSetCookieMiddleware()
    
    public nonisolated init(hostURL: URL, accessToken: String?, userId: String?) {
        self.hostURL = hostURL
        self.accessToken = accessToken
        self.userId = userId
        urlSession = URLSession(configuration: URLSessionConfiguration.default)
        client = Client(
            serverURL: hostURL,
            transport: URLSessionTransport(configuration: .init(session: urlSession)),
            middlewares: [
                AccessTokenAuthenticationMiddleware(accessToken: accessToken),
                grpcSetCookieMiddleware
            ]
        )
    }
    
    public func memoVisibilities() -> [MemoVisibility] {
        return [.private, .local, .public]
    }
    
    public func listMemos() async throws -> [Memo] {
        guard let userId = userId else { throw MoeMemosError.notLogin }
        var memos = [Memo]()
        var nextPageToken: String? = nil
        
        repeat {
            let resp = try await client.MemoService_ListMemos(query: .init(pageSize: 100, pageToken: nextPageToken, filter: "creator == \"users/\(userId)\" && state == \"NORMAL\" && order_by_pinned == true", view: .MEMO_VIEW_FULL))
            let data = try resp.ok.body.json
            memos += data.memos?.map { $0.toMemo(host: hostURL) } ?? []
            nextPageToken = data.nextPageToken
        } while (nextPageToken?.isEmpty == false)
        
        return memos
    }
    
    public func listArchivedMemos() async throws -> [Memo] {
        guard let userId = userId else { throw MoeMemosError.notLogin }
        var memos = [Memo]()
        var nextPageToken: String? = nil
        
        repeat {
            let resp = try await client.MemoService_ListMemos(query: .init(pageSize: 100, pageToken: nextPageToken, filter: "creator == \"users/\(userId)\" && state == \"ARCHIVED\"", view: .MEMO_VIEW_FULL))
            let data = try resp.ok.body.json
            memos += data.memos?.map { $0.toMemo(host: hostURL) } ?? []
            nextPageToken = data.nextPageToken
        } while (nextPageToken?.isEmpty == false)
        
        return memos
    }
    
    public func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?) {
        let resp = try await client.MemoService_ListMemos(query: .init(pageSize: Int32(pageSize), pageToken: pageToken, filter: "state == \"NORMAL\" && visibilities == ['PUBLIC', 'PROTECTED']", view: .MEMO_VIEW_FULL))
        let data = try resp.ok.body.json
        return (data.memos?.map { $0.toMemo(host: hostURL) } ?? [], data.nextPageToken)
    }
    
    public func createMemo(content: String, visibility: MemoVisibility?, resources: [Resource], tags: [String]?) async throws -> Memo {
        let resp = try await client.MemoService_CreateMemo(body: .json(.init(content: content, visibility: visibility.map(MemosV1Visibility.init(memoVisibility:)))))
        let memo = try resp.ok.body.json
        
        var result = memo.toMemo(host: hostURL)
        if resources.isEmpty {
            return result
        }
        
        guard let name = memo.name else { throw MoeMemosError.unsupportedVersion }
        let setResourceResp = try await client.MemoService_SetMemoResources(path: .init(name: name), body: .json(.init(resources: resources.compactMap {
            guard let remoteId = $0.remoteId else { return nil }
            let (name, uid) = getNameAndUid(remoteId: remoteId)
            return MemosV1Resource(name: name, uid: uid)
        })))
        _ = try setResourceResp.ok
        result.resources = resources
        return result
    }
    
    public func updateMemo(remoteId: String, content: String?, resources: [Resource]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> Memo {
        let resp = try await client.MemoService_UpdateMemo(path: .init(memo_name: getName(remoteId: remoteId)), body: .json(.init(
            updateTime: .now,
            content: content,
            visibility: visibility.map(MemosV1Visibility.init(memoVisibility:)),
            pinned: pinned
        )))
        let memo = try resp.ok.body.json
        var result = memo.toMemo(host: hostURL)
        
        guard let resources = resources, Set(resources.map { $0.remoteId }) != Set(result.resources.map { $0.remoteId }) else { return result }
        let setResourceResp = try await client.MemoService_SetMemoResources(path: .init(name: getName(remoteId: remoteId)), body: .json(.init(resources: resources.compactMap {
            guard let remoteId = $0.remoteId else { return nil }
            let (name, uid) = getNameAndUid(remoteId: remoteId)
            return MemosV1Resource(name: name, uid: uid)
        })))
        _ = try setResourceResp.ok
        result.resources = resources
        return result
    }
    
    public func deleteMemo(remoteId: String) async throws {
        let resp = try await client.MemoService_DeleteMemo(path: .init(name_4: getName(remoteId: remoteId)))
        _ = try resp.ok
    }
    
    public func archiveMemo(remoteId: String) async throws {
        let resp = try await client.MemoService_UpdateMemo(path: .init(memo_name: getName(remoteId: remoteId)), body: .json(.init(state: .ARCHIVED)))
        _ = try resp.ok
    }
    
    public func restoreMemo(remoteId: String) async throws {
        let resp = try await client.MemoService_UpdateMemo(path: .init(memo_name: getName(remoteId: remoteId)), body: .json(.init(state: .NORMAL)))
        _ = try resp.ok
    }
    
    public func listTags() async throws -> [Tag] {
        guard let userId = userId else { throw MoeMemosError.notLogin }
        let resp = try await client.MemoService_ListMemos(query: .init(pageSize: 1000000, filter: "creator == \"users/\(userId)\" && state == \"NORMAL\"", view: .MEMO_VIEW_METADATA_ONLY))
        
        var tags = Set<String>()
        for memo in try resp.ok.body.json.memos ?? [] {
            tags.formUnion(memo.tags ?? [])
        }
        return tags.map { Tag(name: $0) }
    }
    
    public func deleteTag(name: String) async throws {
        let resp = try await client.MemoService_DeleteMemoTag(path: .init(parent: "memos/-", tag: name), query: .init(deleteRelatedMemos: false))
        _ = try resp.ok
    }
    
    public func listResources() async throws -> [Resource] {
        let resp = try await client.ResourceService_ListResources()
        let data = try resp.ok.body.json
        return data.resources?.map { $0.toResource(host: hostURL) } ?? []
    }
    
    public func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource {
        let resp = try await client.ResourceService_CreateResource(body: .json(.init(
            filename: filename,
            content: .init(data),
            _type: type,
            memo: memoRemoteId.map(getName(remoteId:))
        )))
        let data = try resp.ok.body.json
        return data.toResource(host: hostURL)
    }
    
    public func deleteResource(remoteId: String) async throws {
        let resp = try await client.ResourceService_DeleteResource(path: .init(name_3: getName(remoteId: remoteId)))
        _ = try resp.ok
    }
    
    public func getCurrentUser() async throws -> User {
        let resp = try await client.AuthService_GetAuthStatus()
        
        if case .default(statusCode: let statusCode, _) = resp, statusCode == HTTPResponse.Status.unauthorized.code {
            throw MoeMemosError.notLogin
        }
        
        let user = try resp.ok.body.json
        
        guard let name = user.name else { throw MoeMemosError.unsupportedVersion }
        let userSettingResp = try await client.UserService_GetUserSetting(path: .init(name: name))
        
        let setting = try userSettingResp.ok.body.json
        return await toUser(user, setting: setting)
    }
    
    public func getWorkspaceProfile() async throws -> MemosV1Profile {
        let resp = try await client.WorkspaceService_GetWorkspaceProfile()
        return try resp.ok.body.json
    }
    
    public func download(url: URL, mimeType: String? = nil) async throws -> URL {
        return try await ServiceUtils.download(urlSession: urlSession, url: url, mimeType: mimeType, middleware: rawAccessTokenMiddlware(hostURL: hostURL, accessToken: accessToken))
    }
    
    func downloadData(url: URL) async throws -> Data {
        return try await ServiceUtils.downloadData(urlSession: urlSession, url: url, middleware: rawAccessTokenMiddlware(hostURL: hostURL, accessToken: accessToken))
    }
    
    private func getName(remoteId: String) -> String {
        return remoteId.split(separator: "|").first.map(String.init) ?? ""
    }
    
    private func getId(remoteId: String) -> String {
        return remoteId.split(separator: "|").first?.split(separator: "/").last.map(String.init) ?? ""
    }
    
    private func getNameAndUid(remoteId: String) -> (String, String) {
        let components = remoteId.split(separator: "|").map(String.init)
        let name = components.first ?? ""
        let uid = components.count > 1 ? components[1] : ""
        return (name, uid)
    }
    
    func toUser(_ memosUser: MemosV1User, setting: Components.Schemas.apiv1UserSetting? = nil) async -> User {
        let remoteId = getId(remoteId: memosUser.name ?? "0")
        let key = "memos:\(hostURL.absoluteString):\(remoteId)"
        let user = User(
            accountKey: key,
            nickname: memosUser.nickname ?? memosUser.username ?? "",
            creationDate: memosUser.createTime ?? .now,
            email: memosUser.email,
            remoteId: remoteId
        )
        if let avatarUrl = memosUser.avatarUrl, let url = URL(string: avatarUrl) {
            var url = url
            if url.host() == nil {
                url = hostURL.appending(path: avatarUrl)
            }
            user.avatarData = try? await downloadData(url: url)
        }
        if let visibilityString = setting?.memoVisibility, let visibility = MemosV1Visibility(rawValue: visibilityString) {
            user.defaultVisibility = visibility.toMemoVisibility()
        }
        return user
    }
}
