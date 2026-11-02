import Foundation
import HTTPTypes
import OpenAPIRuntime

actor MemosAPIRoutingMiddleware: ClientMiddleware {
    private var usesUnversionedAPI: Bool?

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if usesUnversionedAPI == nil {
            var profileRequest = request
            profileRequest.method = .get
            profileRequest.path = "/api/v1/instance/profile"
            profileRequest.headerFields[.contentLength] = nil
            profileRequest.headerFields[.contentType] = nil
            var result = try await next(profileRequest, nil, baseURL)
            var unversioned = false
            if result.0.status == .notFound || result.0.status == .gone {
                profileRequest.path = "/api/instance/profile"
                result = try await next(profileRequest, nil, baseURL)
                unversioned = true
            }
            guard (200..<300).contains(result.0.status.code) else {
                return result
            }
            usesUnversionedAPI = unversioned
            if operationID == "InstanceService_GetInstanceProfile" {
                return result
            }
        }

        var request = request
        if usesUnversionedAPI == true, let path = request.path, path.hasPrefix("/api/v1/") {
            request.path = "/api/" + path.dropFirst("/api/v1/".count)
        }
        return try await next(request, body, baseURL)
    }
}
