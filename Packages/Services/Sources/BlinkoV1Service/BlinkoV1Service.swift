//
//  BlinkoV1Service.swift
//  Services
//
//  Created by Mudkip on 2025/2/1.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes
import Models
import ServiceUtils

@MainActor
public final class BlinkoV1Service: RemoteService {
    private let hostURL: URL
    private let urlSession: URLSession
    private let client: Client
    private let accessToken: String?
    private let dateFormatter = ISO8601DateFormatter()

    public nonisolated init(hostURL: URL, accessToken: String?) {
        self.hostURL = hostURL
        self.accessToken = accessToken
        urlSession = URLSession(configuration: URLSessionConfiguration.default)
        client = Client(
            serverURL: hostURL,
            transport: URLSessionTransport(configuration: .init(session: urlSession)),
            middlewares: [
                AccessTokenAuthenticationMiddleware(accessToken: accessToken),
            ]
        )
    }

    
    public func memoVisibilities() -> [Models.MemoVisibility] {
        return [.private, .public]
    }
    
    public func listMemos() async throws -> [Models.Memo] {
        let resp = try await client.notes_hyphen_list(body: .json(.init(page: 1, size: 200)))
        let memos = try resp.ok.body.json.map { item in
            Memo(
                content: item.content,
                pinned: item.isTop,
                rowStatus: item.isArchived ? .archived : .normal,
                visibility: .private,
                resources: item.attachments.map {
                    Resource(
                        filename: $0.name,
                        size: Int($0.size?.value2 ?? 0),
                        mimeType: "",
                        createdAt: dateFormatter.date(from: $0.createdAt) ?? .now,
                        updatedAt: dateFormatter.date(from: $0.updatedAt) ?? .now,
                        remoteId: $0.path,
                        url: hostURL.appending(path: $0.path)
                    )
                },
                createdAt: dateFormatter.date(from: item.createdAt) ?? .now,
                updatedAt: dateFormatter.date(from: item.updatedAt) ?? .now,
                remoteId: "\(item.id)"
            )
        }
        return memos
    }
    
    public func listArchivedMemos() async throws -> [Models.Memo] {
        let resp = try await client.notes_hyphen_list(body: .json(.init(page: 1, size: 200, isArchived: .init(value1: true))))
        let memos = try resp.ok.body.json.map { item in
            Memo(
                content: item.content,
                pinned: item.isTop,
                rowStatus: item.isArchived ? .archived : .normal,
                visibility: item.isShare ? .public : .private,
                resources: item.attachments.map {
                    Resource(
                        filename: $0.name,
                        size: Int($0.size?.value2 ?? 0),
                        mimeType: "",
                        createdAt: dateFormatter.date(from: $0.createdAt) ?? .now,
                        updatedAt: dateFormatter.date(from: $0.updatedAt) ?? .now,
                        remoteId: $0.path,
                        url: hostURL.appending(path: $0.path)
                    )
                },
                createdAt: dateFormatter.date(from: item.createdAt) ?? .now,
                updatedAt: dateFormatter.date(from: item.updatedAt) ?? .now,
                remoteId: "\(item.id)"
            )
        }
        return memos
    }
    
    public func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Models.Memo], nextPageToken: String?) {
        let page = Int(pageToken ?? "1") ?? 1
        let resp = try await client.notes_hyphen_publicList(body: .json(.init(page: Double(page), size: Double(pageSize) )))
        let memos = try resp.ok.body.json.map { item in
            Memo(
                content: item.content,
                pinned: item.isTop,
                rowStatus: item.isArchived ? .archived : .normal,
                visibility: item.isShare ? .public : .private,
                resources: item.attachments.map {
                    Resource(
                        filename: $0.name,
                        size: Int($0.size?.value2 ?? 0),
                        mimeType: $0._type,
                        createdAt: dateFormatter.date(from: $0.createdAt) ?? .now,
                        updatedAt: dateFormatter.date(from: $0.updatedAt) ?? .now,
                        remoteId: $0.path,
                        url: hostURL.appending(path: $0.path)
                    )
                },
                createdAt: dateFormatter.date(from: item.createdAt) ?? .now,
                updatedAt: dateFormatter.date(from: item.updatedAt) ?? .now,
                remoteId: "\(item.id)"
            )
        }
        return (memos, "\(page + 1)")
    }
    
    public func createMemo(content: String, visibility: Models.MemoVisibility?, resources: [Models.Resource], tags: [String]?) async throws -> Models.Memo {
        let resp = try await client.notes_hyphen_upsert(body: .json(.init(
            content: .init(value1: content),
            attachments: resources.compactMap {
                guard let path = $0.remoteId else { return nil }
                return .init(name: $0.filename, path: path, size: .init(value2: Double($0.size)), _type: $0.mimeType)
            },
            isShare: .init(value1: visibility == .public)
        )))
        _ = try resp.ok.body.json
        
        return Memo(
            content: content,
            visibility: visibility ?? .private,
            resources: resources
        )
    }
    
    public func updateMemo(remoteId: String, content: String?, resources: [Models.Resource]?, visibility: Models.MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> Models.Memo {
        let resp = try await client.notes_hyphen_upsert(body: .json(.init(
            content: .init(value1: content),
            attachments: resources?.compactMap {
                guard let path = $0.remoteId else { return nil }
                return .init(name: $0.filename, path: path, size: .init(value2: Double($0.size)), _type: $0.mimeType)
            },
            id: Double(remoteId),
            isTop: pinned.map { .init(value1: $0) }
        )))
        _ = try resp.ok.body.json
        
        return Memo(
            content: content ?? "",
            pinned: pinned ?? false,
            visibility: visibility ?? .private,
            resources: resources ?? [],
            remoteId: remoteId
        )
    }
    
    public func deleteMemo(remoteId: String) async throws {
        guard let id = Double(remoteId) else { return }
        let resp = try await client.notes_hyphen_deleteMany(body: .json(.init(ids: [id])))
        _ = try resp.ok.body.json
    }
    
    public func archiveMemo(remoteId: String) async throws {
        let resp = try await client.notes_hyphen_upsert(body: .json(.init(
            id: Double(remoteId),
            isArchived: .init(value1: true)
        )))
        _ = try resp.ok.body.json
    }
    
    public func restoreMemo(remoteId: String) async throws {
        let resp = try await client.notes_hyphen_upsert(body: .json(.init(
            id: Double(remoteId),
            isArchived: .init(value1: false)
        )))
        _ = try resp.ok.body.json
    }
    
    public func listTags() async throws -> [Models.Tag] {
        let resp = try await client.tags_hyphen_list()
        let json = try resp.ok.body.json
        return json.map { item in
            Tag(name: item.name)
        }
    }
    
    public func deleteTag(name: String) async throws {
        let resp = try await client.tags_hyphen_list()
        let json = try resp.ok.body.json
        guard let tag = json.first(where: { $0.name == name }) else { return }
        let delResp = try await client.tags_hyphen_deleteOnlyTag(body: .json(.init(id: Double(tag.id))))
        _ = try delResp.ok.body.json
    }
    
    public func listResources() async throws -> [Models.Resource] {
        return []
    }
    
    public func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Models.Resource {
        let resp = try await client.uploadFile(body: .multipartForm([
            .file(.init(payload: .init(body: .init(data)), filename: filename))
        ]))
        let json = try resp.ok.body.json
        return Resource(filename: filename, size: Int(json.size ?? 0), mimeType: "", remoteId: json.path, url: hostURL.appending(path: json.path ?? ""))
    }
    
    public func deleteResource(remoteId: String) async throws {
        let resp = try await client.deleteFile(body: .json(.init(attachment_path: remoteId)))
        _ = try resp.ok.body.json
    }
    
    public func getCurrentUser() async throws -> Models.User {
        let resp = try await client.users_hyphen_detail(.init())
        let json = try resp.ok.body.json
        let key = "blinko:\(hostURL.absoluteString):\(json.id)"
        
        return User(
            accountKey: key,
            nickname: json.nickName,
            remoteId: "\(json.id)"
        )
    }
    
    public func logout() async throws {
        return
    }
    
    public func download(url: URL, mimeType: String?) async throws -> URL {
        return try await ServiceUtils.download(urlSession: urlSession, url: url, mimeType: mimeType, middleware: rawAccessTokenMiddlware(hostURL: hostURL, accessToken: accessToken))
    }
}
