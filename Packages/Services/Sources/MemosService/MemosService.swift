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

struct MemosAuthenticationMiddleware: ClientMiddleware {
    let accessToken: String?

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
    let client: Client
    
    init(hostURL: URL, accessToken: String?) {
        self.client = Client(
            serverURL: hostURL,
            transport: URLSessionTransport(),
            middlewares: [
                MemosAuthenticationMiddleware(accessToken: accessToken)
            ]
        )
    }
    
    func signIn(username: String, password: String) async throws -> MemosUser {
        let resp = try await client.signIn(Operations.signIn.Input(body: .json(.init(password: password, username: username))))
        return try resp.ok.body.json
    }
    
    func getCurrentUser() async throws -> MemosUser {
        let resp = try await client.getCurrentUser()
        return try resp.ok.body.json
    }
}
