//
//  GRPCSetCookieMiddleware.swift
//
//
//  Created by Mudkip on 2024/6/10.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes

public struct GRPCSetCookieMiddleware: ClientMiddleware {
    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var (response, body) = try await next(request, body, baseURL)
        
        // The HTTP response of Memos 0.22.0 uses incorrect cookie header
        guard let grpcSetCookieHeader = HTTPField.Name("grpc-metadata-set-cookie") else { return (response, body) }
        if response.headerFields.contains(grpcSetCookieHeader) && !response.headerFields.contains(.setCookie) {
            response.headerFields[.setCookie] = response.headerFields[grpcSetCookieHeader]
        }
        
        return (response, body)
    }
}
