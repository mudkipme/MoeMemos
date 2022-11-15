//
//  APIBase.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

protocol MemosAPI {
    associatedtype Param = Void
    associatedtype Input: Encodable = Data
    associatedtype Output: Decodable = Data
    
    static var method: HTTPMethod { get }
    static var encodeMode: HTTPBodyEncodeMode { get }
    static var decodeMode: HTTPBodyDecodeMode { get }
    static func path(_ param: Param) -> String
}

struct MemosOutput<T: Decodable>: Decodable {
    let data: T
}

struct MemosSignIn: MemosAPI {
    struct Input: Encodable {
        let email: String
        let password: String
    }

    typealias Output = MemosOutput<MemosUser>
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Void) -> String { "/api/auth/signin" }
}

struct MemosLogout: MemosAPI {
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .none
    static func path(_ params: Void) -> String { "/api/auth/logout" }
}

struct MemosMe: MemosAPI {
    typealias Output = MemosOutput<MemosUser>
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Void) -> String { "/api/user/me" }
}

struct MemosListMemo: MemosAPI {
    struct Input: Encodable {
        let creatorId: Int?
        let rowStatus: MemosRowStatus?
        let visibility: MemosVisibility?
    }

    typealias Output = MemosOutput<[Memo]>
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .urlencoded
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Void) -> String { "/api/memo" }
}

struct MemosTag: MemosAPI {
    struct Input: Encodable {
        let creatorId: Int?
    }

    typealias Output = MemosOutput<[String]>
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .urlencoded
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Void) -> String { "/api/tag" }
}


struct MemosCreate: MemosAPI {
    struct Input: Encodable {
        let content: String
        let visibility: MemosVisibility?
        let resourceIdList: [Int]?
    }

    typealias Output = MemosOutput<Memo>
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Void) -> String { "/api/memo" }
}

struct MemosOrganizer: MemosAPI {
    struct Input: Encodable {
        let pinned: Bool
    }

    typealias Output = MemosOutput<Memo>
    typealias Param = Int
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Int) -> String { "/api/memo/\(params)/organizer" }
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

    typealias Output = MemosOutput<Memo>
    typealias Param = Int
    
    static let method: HTTPMethod = .patch
    static let encodeMode: HTTPBodyEncodeMode = .json
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Int) -> String { "/api/memo/\(params)" }
}

struct MemosDelete: MemosAPI {
    typealias Output = Bool
    typealias Param = Int
    
    static let method: HTTPMethod = .delete
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Int) -> String { "/api/memo/\(params)" }
}

struct MemosListResource: MemosAPI {
    typealias Output = MemosOutput<[Resource]>
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Void) -> String { "/api/resource" }
}

struct MemosUploadResource: MemosAPI {
    typealias Input = [Multipart]
    typealias Output = MemosOutput<Resource>
    
    static let method: HTTPMethod = .post
    static let encodeMode: HTTPBodyEncodeMode = .multipart(boundary: UUID().uuidString)
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Void) -> String { "/api/resource" }
}

struct MemosDeleteResource: MemosAPI {
    typealias Output = Bool
    typealias Param = Int
    
    static let method: HTTPMethod = .delete
    static let encodeMode: HTTPBodyEncodeMode = .none
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Int) -> String { "/api/resource/\(params)" }
}

struct MemosErrorOutput: Decodable {
    let error: String
    let message: String
}

extension MemosAPI {
    static func request(_ memos: Memos, data: Input?, param: Param) async throws -> Output {
        var url = memos.host.appendingPathComponent(path(param))
                
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
        
        return try decodeMode.decode(data)
    }
}
