//
//  APIBase.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

protocol MemosAPI {
    associatedtype Param = ()
    associatedtype Input: Encodable = Data
    associatedtype Output: Decodable = Data
    
    static var path: String { get }
    static var method: HTTPMethod { get }
    static var encodeMode: HTTPBodyEncodeMode { get }
    static var decodeMode: HTTPBodyDecodeMode { get }
    static func path(_ param: Param) -> String
}

extension MemosAPI {
    static var path: String {
        return "/"
    }
}

extension MemosAPI where Self.Param == () {
    static func path(_ param: Param) -> String {
        return Self.path
    }
}

struct MemosOutput<T: Decodable>: Decodable {
    let data: T
}

struct MemosSignIn: MemosAPI {
    struct Input: Encodable {
        let email: String
        let username: String
        let password: String
    }
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .none
    static let path = "/api/v1/auth/signin"
}

struct MemosLogout: MemosAPI {
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .none
    static let path = "/api/v1/auth/signout"
}

struct MemosMe: MemosAPI {
    typealias Output = MemosUser
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/user/me"
}

struct MemosListMemo: MemosAPI {
    struct Input: Encodable {
        let creatorId: Int?
        let rowStatus: MemosRowStatus?
        let visibility: MemosVisibility?
    }

    typealias Output = [Memo]
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .urlencoded
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/memo"
}

struct MemosTag: MemosAPI {
    struct Input: Encodable {
        let creatorId: Int?
    }

    typealias Output = [String]
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .urlencoded
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/tag"
}

struct MemosCreate: MemosAPI {
    struct Input: Encodable {
        let content: String
        let visibility: MemosVisibility?
        let resourceIdList: [Int]?
    }

    typealias Output = Memo
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/memo"
}

struct MemosOrganizer: MemosAPI {
    struct Input: Encodable {
        let pinned: Bool
    }

    typealias Output = Memo
    typealias Param = Int
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Int) -> String { "/api/v1/memo/\(params)/organizer" }
}

struct MemosPatch: MemosAPI {
    struct Input: Encodable {
        let id: Int
        let createdTs: Date?
        let rowStatus: MemosRowStatus?
        let content: String?
        let visibility: MemosVisibility?
        let resourceIdList: [Int]?
    }

    typealias Output = Memo
    typealias Param = Int
    
    static let method: HTTPMethod = .patch
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Int) -> String { "/api/v1/memo/\(params)" }
}

struct MemosDelete: MemosAPI {
    typealias Param = Int
    
    static let method: HTTPMethod = .delete
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .none
    static func path(_ params: Int) -> String { "/api/v1/memo/\(params)" }
}

struct MemosListResource: MemosAPI {
    typealias Output = [Resource]
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/resource"
}

struct MemosUploadResource: MemosAPI {
    typealias Input = [Multipart]
    typealias Output = Resource
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .multipart(boundary: UUID().uuidString)
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/resource/blob"
}

struct MemosUploadResourceLegacy: MemosAPI {
    typealias Input = [Multipart]
    typealias Output = MemosOutput<Resource>
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .multipart(boundary: UUID().uuidString)
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/resource"
}

struct MemosDeleteResource: MemosAPI {
    typealias Param = Int
    
    static let method: HTTPMethod = .delete
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .none
    static func path(_ params: Int) -> String { "/api/v1/resource/\(params)" }
}

struct MemosV0Status: MemosAPI {
    typealias Output = MemosOutput<MemosServerStatus>
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/status"
}

struct MemosStatus: MemosAPI {
    typealias Output = MemosServerStatus
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/status"
}

struct MemosUpsertTag: MemosAPI {
    struct Input: Encodable {
        let name: String
    }

    typealias Output = String
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/tag"
}

struct MemosListAllMemo: MemosAPI {
    struct Input: Encodable {
        let pinned: Bool?
        let tag: String?
        let visibility: MemosVisibility?
        let limit: Int?
        let offset: Int?
    }
    
    typealias Output = [Memo]

    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .urlencoded
    static let decodeMode: HTTPBodyDecodeMode = .json
    static let path = "/api/v1/memo/all"
}

struct MemosErrorOutput: Decodable {
    let error: String
    let message: String
}

fileprivate extension String {
    func replacingPrefix(_ prefix: String, with newPrefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return newPrefix + String(self.dropFirst(prefix.count))
    }
}

extension MemosAPI {
    static func request(_ memos: Memos, data: Input?, param: Param) async throws -> Output {
        var path = Self.path(param)
        var useLegacy = false
        
        // support legacy versions
        if Self.self == MemosSignIn.self {
            useLegacy = memos.status?.profile.version.compare("0.13.2", options: .numeric) == .orderedAscending && path.hasPrefix("/api/v1/")
        } else  {
            useLegacy = memos.status?.profile.version.compare("0.14.0", options: .numeric) == .orderedAscending && path.hasPrefix("/api/v1/")
        }
        if useLegacy {
            path = path.replacingPrefix("/api/v1/", with: "/api/")
        }
        
        var url = memos.host.appendingPathComponent(path)
        
        if method == .get && encodeMode == .urlencoded && data != nil {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = try encodeToQueryItems(data)
            url = components.url!
        }
        
        if let openId = memos.openId, !openId.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "openId", value: openId))
            components.queryItems = queryItems
            url = components.url!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if let accept = decodeMode.contentType() {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }

        if (method == .post || method == .put || method == .patch) && data != nil {
            if let contentType = encodeMode.contentType() {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            request.httpBody = try encodeMode.encode(data)
        }
        
        let (data, response) = try await memos.session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw MemosError.unknown
        }
        if response.statusCode < 200 || response.statusCode >= 300 {
            let errorOutput: MemosErrorOutput
            do {
                errorOutput = try decodeMode.decode(data)
            } catch {
                throw MemosError.invalidStatusCode(response.statusCode, String(data: data, encoding: .utf8))
            }
            throw MemosError.invalidStatusCode(response.statusCode, errorOutput.message)
        }
        
        if useLegacy && decodeMode == .json {
            let json: MemosOutput<Output> = try decodeMode.decode(data)
            return json.data
        }
        
        return try decodeMode.decode(data)
    }
}
