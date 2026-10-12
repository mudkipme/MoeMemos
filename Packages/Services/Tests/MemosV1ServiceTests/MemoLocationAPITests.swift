import Foundation
import HTTPTypes
import Models
import OpenAPIRuntime
import XCTest
@testable import MemosV1Service

@MainActor
final class MemoLocationAPITests: XCTestCase {
    func testCreateSendsMemosLocationAndDecodesResponse() async throws {
        let transport = LocationTransport()
        let service = MemosV1Service(hostURL: URL(string: "https://memos.example")!, accessToken: nil, userId: "1", transport: transport)
        let location = MemoLocation(placeholder: "Equator", latitude: 0, longitude: -45.5)
        let memo = try await service.createMemo(content: "Here", visibility: .private, resources: [], tags: nil,
                                                createdAt: nil, updatedAt: nil, location: location)
        XCTAssertEqual(memo.location, location)
        let body = try JSONSerialization.jsonObject(with: await transport.body) as? [String: Any]
        let payload = try XCTUnwrap(body?["location"] as? [String: Any])
        XCTAssertEqual(payload["placeholder"] as? String, "Equator")
        XCTAssertEqual(payload["latitude"] as? Double, 0)
        XCTAssertEqual(payload["longitude"] as? Double, -45.5)
    }

    func testSetRemoveAndUnrelatedUpdatesUseExplicitMasks() async throws {
        let transport = LocationTransport()
        let service: any RemoteService = MemosV1Service(hostURL: URL(string: "https://memos.example")!, accessToken: nil, userId: "1", transport: transport)
        let place = MemoLocation(placeholder: "Tokyo", latitude: 35.68, longitude: 139.69)
        _ = try await service.updateMemo(remoteId: "memos/one", content: nil, resources: nil, visibility: nil,
                                         tags: nil, pinned: nil, updatedAt: nil, location: .set(place))
        let setPath = await transport.path
        XCTAssertEqual(mask(setPath), ["update_time", "location"])
        let setBody = try JSONSerialization.jsonObject(with: await transport.body) as? [String: Any]
        XCTAssertNotNil(setBody?["location"])
        _ = try await service.updateMemo(remoteId: "memos/one", content: nil, resources: nil, visibility: nil,
                                         tags: nil, pinned: nil, updatedAt: nil, location: .remove)
        let removePath = await transport.path
        XCTAssertEqual(mask(removePath), ["update_time", "location"])
        let removeBody = try JSONSerialization.jsonObject(with: await transport.body) as? [String: Any]
        XCTAssertNil(removeBody?["location"], "Omitted location plus the mask clears the server value")
        _ = try await service.updateMemo(remoteId: "memos/one", content: "Changed", resources: nil, visibility: nil,
                                         tags: nil, pinned: true, updatedAt: nil)
        let contentPath = await transport.path
        XCTAssertEqual(mask(contentPath), ["update_time", "content", "pinned"])
        let contentBody = try JSONSerialization.jsonObject(with: await transport.body) as? [String: Any]
        XCTAssertNil(contentBody?["location"])
    }

    func testServerProtoDefaultsPreserveZeroCoordinates() throws {
        let payload = Data(#"{"content":"Origin","location":{"placeholder":""}}"#.utf8)
        let memo = try JSONDecoder().decode(Components.Schemas.Memo.self, from: payload).toMemo(host: URL(string: "https://memos.example")!)
        XCTAssertEqual(memo.location, MemoLocation(latitude: 0, longitude: 0))
    }

    private func mask(_ path: String?) -> Set<String> {
        let components = URLComponents(string: path ?? "")
        let value = components?.queryItems?.first { $0.name == "updateMask" }?.value ?? ""
        return Set(value.split(separator: ",").map(String.init))
    }
}

private actor LocationTransport: ClientTransport {
    var path: String?
    var body = Data()

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        self.path = request.path
        self.body = try await body.mapData() ?? Data()
        var memo = try JSONSerialization.jsonObject(with: self.body) as? [String: Any] ?? [:]
        memo["name"] = "memos/one"
        let response = HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"])
        return (response, HTTPBody(try JSONSerialization.data(withJSONObject: memo)))
    }
}

private extension Optional where Wrapped == HTTPBody {
    func mapData() async throws -> Data? {
        guard let body = self else { return nil }
        return try await Data(collecting: body, upTo: 1_000_000)
    }
}
