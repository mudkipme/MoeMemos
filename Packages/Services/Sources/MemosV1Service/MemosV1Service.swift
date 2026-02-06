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
            let resp = try await client.MemoService_ListMemos(query: .init(pageSize: 200, pageToken: nextPageToken, state: .NORMAL, filter: "creator_id == \(userId)"))
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
            let resp = try await client.MemoService_ListMemos(query: .init(pageSize: 200, pageToken: nextPageToken, state: .ARCHIVED, filter: "creator_id == \(userId)"))
            let data = try resp.ok.body.json
            memos += data.memos?.map { $0.toMemo(host: hostURL) } ?? []
            nextPageToken = data.nextPageToken
        } while (nextPageToken?.isEmpty == false)
        
        return memos
    }
    
    public func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?) {
        let resp = try await client.MemoService_ListMemos(query: .init(pageSize: 200, pageToken: pageToken, filter: "visibility in [\"PUBLIC\", \"PROTECTED\"]"))
        let data = try resp.ok.body.json
        return (data.memos?.map { $0.toMemo(host: hostURL) } ?? [], data.nextPageToken)
    }
    
    public func createMemo(
        content: String,
        visibility: MemoVisibility?,
        resources: [Resource],
        tags: [String]?,
        createdAt: Date?,
        updatedAt: Date?
    ) async throws -> Memo {
        _ = tags
        let memosResources: [MemosV1Resource] = resources.compactMap {
            var resource: MemosV1Resource? = nil
            if let remoteId = $0.remoteId {
                resource = MemosV1Resource(name: getName(remoteId: remoteId))
            }
            return resource
        }
        
        let resp = try await client.MemoService_CreateMemo(body: .json(.init(
            createTime: createdAt,
            updateTime: updatedAt,
            content: content,
            visibility: visibility.map(MemosV1Visibility.init(memoVisibility:)),
            attachments: memosResources
        )))
        let memo = try resp.ok.body.json
        
        let result = memo.toMemo(host: hostURL)
        return result
    }
    
    public func updateMemo(
        remoteId: String,
        content: String?,
        resources: [Resource]?,
        visibility: MemoVisibility?,
        tags: [String]?,
        pinned: Bool?,
        updatedAt: Date?
    ) async throws -> Memo {
        _ = tags
        let memosResources: [MemosV1Resource]? = resources?.compactMap {
            var resource: MemosV1Resource? = nil
            if let remoteId = $0.remoteId {
                resource = MemosV1Resource(name: getName(remoteId: remoteId))
            }
            return resource
        }

        let resp = try await client.MemoService_UpdateMemo(path: .init(memo: getId(remoteId: remoteId)), body: .json(.init(
            updateTime: updatedAt ?? .now,
            content: content,
            visibility: visibility.map(MemosV1Visibility.init(memoVisibility:)),
            pinned: pinned,
            attachments: memosResources
        )))
        let memo = try resp.ok.body.json
        let result = memo.toMemo(host: hostURL)
        return result
    }
    
    public func deleteMemo(remoteId: String) async throws {
        let resp = try await client.MemoService_DeleteMemo(path: .init(memo: getId(remoteId: remoteId)))
        _ = try resp.ok
    }
    
    public func archiveMemo(remoteId: String) async throws {
        let resp = try await client.MemoService_UpdateMemo(path: .init(memo: getId(remoteId: remoteId)), body: .json(.init(state: .ARCHIVED)))
        _ = try resp.ok
    }
    
    public func restoreMemo(remoteId: String) async throws {
        let resp = try await client.MemoService_UpdateMemo(path: .init(memo: getId(remoteId: remoteId)), body: .json(.init(state: .NORMAL)))
        _ = try resp.ok
    }
    
    public func listTags() async throws -> [Tag] {
        guard let userId = userId else { throw MoeMemosError.notLogin }
        let resp = try await client.UserService_GetUserStats(path: .init(user: "\(userId)"))
        let data = try resp.ok.body.json
        
        var tags = [Tag]()
        if let tagCount = data.tagCount?.additionalProperties {
            for (tag, _) in tagCount {
                tags.append(.init(name: tag))
            }
        }
        return tags
    }
    
    public func listResources() async throws -> [Resource] {
        let resp = try await client.AttachmentService_ListAttachments()
        let data = try resp.ok.body.json
        return data.attachments?.map { $0.toResource(host: hostURL) } ?? []
    }
    
    public func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource {
        let resp = try await client.AttachmentService_CreateAttachment(body: .json(.init(
            filename: filename,
            content: .init(data),
            _type: type,
            memo: memoRemoteId.map(getName(remoteId:))
        )))
        let data = try resp.ok.body.json
        return data.toResource(host: hostURL)
    }
    
    public func deleteResource(remoteId: String) async throws {
        let resp = try await client.AttachmentService_DeleteAttachment(path: .init(attachment: getId(remoteId: remoteId)))
        _ = try resp.ok
    }
    
    public func getCurrentUser() async throws -> User {
        let resp = try await client.AuthService_GetCurrentUser()
        
        let json = try resp.ok.body.json
        guard let user = json.user?.value1 else {
            throw MoeMemosError.notLogin
        }
        
        guard let name = user.name else { throw MoeMemosError.unsupportedVersion }
        let userSettingResp = try await client.UserService_GetUserSetting(path: .init(user: getId(remoteId: name), setting: "GENERAL"))
        
        let setting = try userSettingResp.ok.body.json
        return await toUser(user, setting: setting)
    }
    
    public func getWorkspaceProfile() async throws -> MemosV1Profile {
        let resp = try await client.InstanceService_GetInstanceProfile()
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
    
    func toUser(_ memosUser: MemosV1User, setting: Components.Schemas.UserSetting? = nil) async -> User {
        let remoteId = getId(remoteId: memosUser.name ?? "0")
        let key = "memos:\(hostURL.absoluteString):\(remoteId)"
        let user = User(
            accountKey: key,
            nickname: memosUser.displayName ?? memosUser.username,
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
        if let visibilityString = setting?.generalSetting?.memoVisibility, let visibility = MemosV1Visibility(rawValue: visibilityString) {
            user.defaultVisibility = visibility.toMemoVisibility()
        }
        return user
    }
}
