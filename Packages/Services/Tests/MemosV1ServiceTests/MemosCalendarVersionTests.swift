import Foundation
import HTTPTypes
import Models
import OpenAPIRuntime
import XCTest
@testable import MemosV1Service

@MainActor
final class MemosCalendarVersionTests: XCTestCase {
    func testCalendarVersionsSupportLoginSyncCommentsTagsAndWrites() async throws {
        let versions: [(String, HTTPResponse.Status)] = [
            ("26.10.0", .gone), ("26.11.0", .notFound), ("26.11.1", .notFound), ("26.11.2", .notFound)
        ]
        for (version, status) in versions {
            let hasMemoParent = version == "26.11.2"
            let transport = CompatibilityTransport(version: version, legacyStatus: status)
            let service = MemosV1Service(hostURL: URL(string: "https://memos.example/notes")!, accessToken: "test-token", userId: "alice", transport: transport)

            let memos = try await service.listMemos()
            XCTAssertEqual(memos.map(\.content), ["Memo"])
            let user = try await service.getCurrentUser()
            XCTAssertEqual(user.remoteId, "alice")
            XCTAssertEqual(user.defaultVisibility, .local)
            let archived = try await service.listArchivedMemos()
            XCTAssertEqual(archived.map(\.content), ["Memo"])
            let workspace = try await service.listWorkspaceMemos(pageSize: 20, pageToken: nil)
            XCTAssertEqual(workspace.list.map(\.content), ["Memo"])
            let comments = try await service.listMemoComments(memoRemoteId: "memos/one|legacy")
            XCTAssertEqual(comments.map(\.content), ["Comment", "Next comment"])
            let tags = try await service.listTags()
            XCTAssertEqual(tags.map(\.name), ["swift"])
            let created = try await service.createMemo(content: "Created", visibility: .private, resources: [], tags: nil, createdAt: nil, updatedAt: nil)
            XCTAssertEqual(created.content, "Created")
            let comment = try await service.createMemoComment(memoRemoteId: "memos/one|legacy", content: "Reply")
            XCTAssertEqual(comment.content, "Reply")
            let attachment = try await service.createResource(filename: "note.txt", data: Data("file".utf8), type: "text/plain", memoRemoteId: nil)
            XCTAssertEqual(attachment.filename, "note.txt")
            try await service.archiveMemo(remoteId: "memos/one")
            try await service.restoreMemo(remoteId: "memos/one")
            try await service.deleteMemo(remoteId: "memos/one")

            let requests = await transport.requests
            XCTAssertEqual(requests.filter { $0.path == "/api/v1/instance/profile" }.count, 1)
            XCTAssertEqual(requests.filter { $0.path == "/api/instance/profile" }.count, 1)
            XCTAssertTrue(requests.dropFirst().allSatisfy { $0.path?.hasPrefix("/api/") == true && $0.path?.hasPrefix("/api/v1/") == false })
            XCTAssertTrue(requests.allSatisfy { $0.headerFields[.authorization] == "Bearer test-token" })

            let memoQueries = requests.filter { $0.method == .get && $0.path?.hasPrefix("/api/memos?") == true }
            let topLevel = hasMemoParent ? " && parent == null" : ""
            XCTAssertEqual(memoQueries.map { queryValue("filter", in: $0.path) }, [
                "creator == \"users/alice\"\(topLevel)",
                "creator == \"users/alice\"\(topLevel)",
                "visibility in [\"PUBLIC\", \"PROTECTED\"]\(topLevel)"
            ] + (hasMemoParent ? Array(repeating: "parent == \"memos/one\"", count: 2) : []))
            XCTAssertEqual(queryValue("state", in: memoQueries.dropFirst().first?.path), "ARCHIVED")
            let stats = requests.first { $0.path?.hasPrefix("/api/users/alice:getStats") == true }
            XCTAssertNotNil(stats)
            XCTAssertEqual(queryValue("filter", in: stats?.path), hasMemoParent ? "parent == null" : nil)
            let commentPath = hasMemoParent ? "/api/memos" : "/api/memos/one/comments"
            let expectedPostPaths = ["/api/memos", commentPath, "/api/attachments"]
            XCTAssertEqual(requests.filter { $0.method == .post }.compactMap(\.path), expectedPostPaths)
            let paginatedCommentRequest = try XCTUnwrap(requests.first { queryValue("pageToken", in: $0.path) == "next" })
            XCTAssertTrue(paginatedCommentRequest.path?.hasPrefix("\(commentPath)?") == true)
            if hasMemoParent {
                XCTAssertFalse(requests.contains { $0.path?.contains("/comments") == true })
            }

            let writes = await transport.writes
            XCTAssertEqual(writes.count, 5)
            let memoBody = try XCTUnwrap(writes.first)
            let memoJSON = try JSONSerialization.jsonObject(with: memoBody) as? [String: Any]
            XCTAssertEqual(memoJSON?["content"] as? String, "Created")
            XCTAssertNil(memoJSON?["parent"])
            let commentBody = try XCTUnwrap(writes.dropFirst().first)
            let commentJSON = try JSONSerialization.jsonObject(with: commentBody) as? [String: Any]
            XCTAssertEqual(commentJSON?["content"] as? String, "Reply")
            XCTAssertEqual(commentJSON?["parent"] as? String, hasMemoParent ? "memos/one" : nil)
            let bases = await transport.baseURLs
            XCTAssertTrue(bases.allSatisfy { $0.absoluteString == "https://memos.example/notes" })
        }
    }

    func testLegacyServersKeepVersionedRoutesAndResponseFields() async throws {
        let transport = CompatibilityTransport(version: "0.31.0")
        let service = MemosV1Service(hostURL: URL(string: "https://memos.example")!, accessToken: nil, userId: "alice", transport: transport)
        _ = try await service.createMemo(content: "Created", visibility: nil, resources: [], tags: nil, createdAt: nil, updatedAt: nil)
        let comments = try await service.listMemoComments(memoRemoteId: "memos/one")
        XCTAssertEqual(comments.map(\.content), ["Comment", "Next comment"])
        let tags = try await service.listTags()
        XCTAssertEqual(tags.map(\.name), ["swift"])
        let requests = await transport.requests
        XCTAssertEqual(requests.first?.path, "/api/v1/instance/profile")
        XCTAssertTrue(requests.allSatisfy { $0.path?.hasPrefix("/api/v1/") == true })
    }

    func testFirstUploadDiscoversCalendarAPIWithoutReplayingTheBody() async throws {
        let transport = CompatibilityTransport(version: "26.11.0", legacyStatus: .notFound)
        let service = MemosV1Service(hostURL: URL(string: "https://memos.example")!, accessToken: nil, userId: "alice", transport: transport)
        _ = try await service.createResource(filename: "note.txt", data: Data("file".utf8), type: "text/plain", memoRemoteId: nil)
        let requests = await transport.requests
        XCTAssertEqual(requests.map(\.path), ["/api/v1/instance/profile", "/api/instance/profile", "/api/attachments"])
        XCTAssertTrue(requests.prefix(2).allSatisfy { $0.method == .get && $0.headerFields[.contentLength] == nil })
        let writes = await transport.writes
        XCTAssertEqual(writes.count, 1)
        let payload = try JSONSerialization.jsonObject(with: XCTUnwrap(writes.first)) as? [String: Any]
        XCTAssertEqual(payload?["content"] as? String, Data("file".utf8).base64EncodedString())
    }

    func testProfileErrorsDoNotTriggerFallbackOrWrites() async throws {
        for status in [HTTPResponse.Status.unauthorized, .internalServerError] {
            let transport = CompatibilityTransport(version: "26.11.0", legacyStatus: status)
            let service = MemosV1Service(hostURL: URL(string: "https://memos.example")!, accessToken: nil, userId: "alice", transport: transport)
            do {
                _ = try await service.createMemo(content: "Created", visibility: nil, resources: [], tags: nil, createdAt: nil, updatedAt: nil)
                XCTFail("Expected profile error")
            } catch let error as MoeMemosError {
                switch status {
                case .unauthorized:
                    if case .accessTokenExpired = error {} else {
                        XCTFail("Expected accessTokenExpired, got \(error)")
                    }
                case .internalServerError:
                    if case .invalidStatusCode(500, let message) = error {
                        XCTAssertEqual(message, "Legacy route unavailable")
                    } else {
                        XCTFail("Expected invalidStatusCode(500), got \(error)")
                    }
                default:
                    XCTFail("Unexpected status \(status)")
                }
            }
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
            XCTAssertEqual(requests.first?.path, "/api/v1/instance/profile")
            let writes = await transport.writes
            XCTAssertTrue(writes.isEmpty)
        }
    }
}

private actor CompatibilityTransport: ClientTransport {
    let version: String
    let legacyStatus: HTTPResponse.Status?
    var requests = [HTTPRequest]()
    var writes = [Data]()
    var baseURLs = [URL]()

    init(version: String, legacyStatus: HTTPResponse.Status? = nil) {
        self.version = version
        self.legacyStatus = legacyStatus
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        requests.append(request)
        baseURLs.append(baseURL)
        if request.path == "/api/v1/instance/profile", let legacyStatus {
            return response(["code": 12, "message": "Legacy route unavailable"], status: legacyStatus)
        }
        if request.path?.hasSuffix("/instance/profile") == true {
            return response(["version": version])
        }
        if let body {
            let data = try await Data(collecting: body, upTo: 1_000_000)
            writes.append(data)
            return (HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]), HTTPBody(data))
        }
        switch operationID {
        case "AuthService_GetCurrentUser":
            return response(["user": ["name": "users/alice", "username": "alice", "role": "ADMIN", "state": "NORMAL"]])
        case "UserService_GetUserSetting":
            return response(["generalSetting": ["memoVisibility": "PROTECTED"]])
        case "UserService_GetUser":
            return response(["name": "users/alice", "username": "alice", "role": "USER", "state": "NORMAL"])
        case "MemoService_ListMemos":
            if version == "26.11.2", queryValue("filter", in: request.path)?.hasPrefix("parent == \"") == true {
                return commentPage("memos", path: request.path)
            }
            return response(["memos": [["name": "memos/one", "content": "Memo"]]])
        case "MemoService_ListMemoComments":
            return commentPage(legacyStatus == nil ? "memos" : "comments", path: request.path)
        case "UserService_GetUserStats":
            return response([legacyStatus == nil ? "tagCount" : "tagCounts": ["swift": 2]])
        default:
            return response([:])
        }
    }

    private func commentPage(_ key: String, path: String?) -> (HTTPResponse, HTTPBody?) {
        let nextPage = queryValue("pageToken", in: path) == "next"
        return response([
            key: [["name": "memos/comment", "content": nextPage ? "Next comment" : "Comment", "creator": "users/alice"]],
            "nextPageToken": nextPage ? "" : "next"
        ])
    }

    private func response(_ json: [String: Any], status: HTTPResponse.Status = .ok) -> (HTTPResponse, HTTPBody?) {
        (HTTPResponse(status: status, headerFields: [.contentType: "application/json"]), HTTPBody(try! JSONSerialization.data(withJSONObject: json)))
    }
}

private func queryValue(_ name: String, in path: String?) -> String? {
    URLComponents(string: path ?? "")?.queryItems?.first { $0.name == name }?.value
}
