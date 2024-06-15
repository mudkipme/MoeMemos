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

public struct AccessTokenAuthenticationMiddleware: ClientMiddleware {
    var accessToken: String?
    
    public init(accessToken: String? = nil) {
        self.accessToken = accessToken
    }

    public func intercept(
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

public func rawAccessTokenMiddlware(hostURL: URL, accessToken: String?) -> @Sendable (URLRequest) async throws -> URLRequest {
    return { request in
        var request = request
        if let accessToken = accessToken, !accessToken.isEmpty && request.url?.host == hostURL.host {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
