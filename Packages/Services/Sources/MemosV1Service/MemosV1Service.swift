//
//  File.swift
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
        fatalError("not implemented")
    }
    
    public func listArchivedMemos() async throws -> [Memo] {
        fatalError("not implemented")
    }
    
    public func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?) {
        let resp = try await client.MemoService_ListMemos(query: .init(pageSize: Int32(pageSize), pageToken: pageToken, filter: "row_status == \"NORMAL\" && visibilities == ['PUBLIC', 'PROTECTED']"))
        let data = try resp.ok.body.json
        return (data.memos?.map { $0.toMemo(host: hostURL) } ?? [], data.nextPageToken)
    }
    
    public func createMemo(content: String, visibility: MemoVisibility?, resources: [Resource], tags: [String]?) async throws -> Memo {
        fatalError("not implemented")
    }
    
    public func updateMemo(remoteId: String, content: String?, resources: [Resource]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> Memo {
        fatalError("not implemented")
    }
    
    public func deleteMemo(remoteId: String) async throws {
        fatalError("not implemented")
    }
    
    public func archiveMemo(remoteId: String) async throws {
        fatalError("not implemented")
    }
    
    public func restoreMemo(remoteId: String) async throws {
        fatalError("not implemented")
    }
    
    public func listTags() async throws -> [Tag] {
        fatalError("not implemented")
    }
    
    public func deleteTag(name: String) async throws {
        fatalError("not implemented")
    }
    
    public func listResources() async throws -> [Resource] {
        fatalError("not implemented")
    }
    
    public func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource {
        fatalError("not implemented")
    }
    
    public func deleteResource(remoteId: String) async throws {
        fatalError("not implemented")
    }
    
    public func getCurrentUser() async throws -> User {
        fatalError("not implemented")
    }
    
    public func logout() async throws {
        fatalError("not implemented")
    }
    
    public func download(url: URL, mimeType: String?) async throws -> URL {
        fatalError("not implemented")
    }
}
