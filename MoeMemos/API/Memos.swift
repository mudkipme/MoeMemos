//
//  Memos.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/6.
//

import Foundation

private let cookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: groupContainerIdentifier)

private let urlSessionConfiguration = {
    let configuration = URLSessionConfiguration.default
    configuration.httpCookieStorage = cookieStorage
    return configuration
}()

class Memos {
    let host: URL
    let openId: String?
    let session: URLSession
    
    init(host: URL, openId: String?) {
        self.host = host
        self.openId = (openId?.isEmpty ?? true) ? nil : openId
        session = URLSession(configuration: urlSessionConfiguration)
        
        // Migrate cookies to group container
        let legacyCookieStorage = HTTPCookieStorage.shared
        if let legacyCookies = legacyCookieStorage.cookies(for: host), !legacyCookies.isEmpty {
            cookieStorage.setCookies(legacyCookies, for: host, mainDocumentURL: nil)
            legacyCookies.forEach(legacyCookieStorage.deleteCookie)
        }
        
        // No longer uses cookie when logged-in with Open API
        if let openId = openId, !openId.isEmpty {
            session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
        }
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
    
    func tags(data: MemosTag.Input?) async throws -> MemosTag.Output {
        return try await MemosTag.request(self, data: data, param: ())
    }
    
    func createMemo(data: MemosCreate.Input) async throws -> MemosCreate.Output {
        return try await MemosCreate.request(self, data: data, param: ())
    }
    
    func updateMemoOrganizer(memoId: Int, data: MemosOrganizer.Input) async throws -> MemosOrganizer.Output {
        return try await MemosOrganizer.request(self, data: data, param: memoId)
    }
    
    func updateMemo(data: MemosPatch.Input) async throws -> MemosPatch.Output {
        return try await MemosPatch.request(self, data: data, param: data.id)
    }
    
    func deleteMemo(id: Int) async throws -> MemosDelete.Output {
        return try await MemosDelete.request(self, data: nil, param: id)
    }
    
    func listResources() async throws -> MemosListResource.Output {
        return try await MemosListResource.request(self, data: nil, param: ())
    }
    
    func uploadResource(imageData: Data, filename: String, contentType: String) async throws -> MemosUploadResource.Output {
        return try await MemosUploadResource.request(self, data: [Multipart(name: "file", filename: filename, contentType: contentType, data: imageData)], param: ())
    }
    
    func deleteResource(id: Int) async throws -> MemosDeleteResource.Output {
        return try await MemosDeleteResource.request(self, data: nil, param: id)
    }
}
