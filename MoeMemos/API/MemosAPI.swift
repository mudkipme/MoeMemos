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

struct MemosSignIn: MemosAPI {
    struct Input: Encodable {
        let email: String
        let password: String
    }

    struct Output: Decodable {
        let data: MemosUser
    }
    
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
    struct Output: Decodable {
        let data: MemosUser
    }
    
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

    struct Output: Decodable {
        let data: [Memo]
    }
    
    static let method: HTTPMethod = .get
    static let encodeMode: HTTPBodyEncodeMode = .urlencoded
    static let decodeMode: HTTPBodyDecodeMode = .json
    static func path(_ params: Void) -> String { "/api/memo" }
}

extension MemosAPI {
    static func request(_ memos: Memos, data: Input?, param: Param) async throws -> Output {
        var url = memos.host.appendingPathComponent(path(param))
                
        if method == .get && encodeMode == .urlencoded && data != nil {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = try encodeToQueryItems(data)
            url = components.url!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
            if response.statusCode == 401 {
                throw MemosError.notLogin
            }
            throw MemosError.invalidStatusCode(response.statusCode)
        }
        
        return try decodeMode.decode(data)
    }
}

class Memos {
    let host: URL
    let session: URLSession
    
    init(host: URL) {
        self.host = host
        session = URLSession.shared
    }
    
    func signIn(data: MemosSignIn.Input) async throws -> MemosSignIn.Output {
        return try await MemosSignIn.request(self, data: data, param: ())
    }
    
    func logout() async throws {
        _ = try await MemosLogout.request(self, data: nil, param: ())
        session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
    }
    
    func me() async throws -> MemosMe.Output {
        return try await MemosMe.request(self, data: nil, param: ())
    }
    
    func listMemos(data: MemosListMemo.Input?) async throws -> MemosListMemo.Output {
        return try await MemosListMemo.request(self, data: data, param: ())
    }
}
