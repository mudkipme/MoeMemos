//
//  FixNamePathMiddleware.swift
//
//
//  Created by Mudkip on 2024/6/19.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes

struct FixNamePathMiddleware: ClientMiddleware {
    func intercept(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String, next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        if let path = request.path, path.contains("%2F") {
            request.path = path.replacingOccurrences(of: "%2F", with: "/")
        }
        return try await next(request, body, baseURL)
    }
}
