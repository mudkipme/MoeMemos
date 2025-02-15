//
//  File.swift
//  
//
//  Created by Mudkip on 2024/6/10.
//

import Foundation
import Models

typealias MemosV1Memo = Components.Schemas.apiv1Memo
typealias MemosV1Resource = Components.Schemas.v1Resource
typealias MemosV1Visibility = Components.Schemas.v1Visibility
public typealias MemosV1User = Components.Schemas.v1User
public typealias MemosV1Profile = Components.Schemas.v1WorkspaceProfile

extension MemosV1Memo {
    func toMemo(host: URL) -> Memo {
        return Memo(
            content: content ?? "",
            pinned: pinned ?? false,
            rowStatus: state == .ARCHIVED ? .archived : .normal,
            visibility: visibility?.toMemoVisibility() ?? .private,
            resources: resources?.map { $0.toResource(host: host) } ?? [],
            createdAt: createTime ?? .now,
            updatedAt: updateTime ?? .now,
            remoteId: name
        )
    }
}

extension MemosV1Resource {
    func url(for hostURL: URL) -> URL {
        if let externalLink = externalLink, !externalLink.isEmpty, let url = URL(string: externalLink) {
            return url
        }
        return hostURL.appending(path: "file").appending(path: name ?? "").appending(path: filename ?? "")
    }
    
    func toResource(host: URL) -> Resource {
        var size = 0
        if let s = self.size, let s = Int(s) {
            size = s
        }
        
        return Resource(
            filename: filename ?? "",
            size: size,
            mimeType: _type ?? "application/octet-stream",
            createdAt: createTime ?? .now,
            updatedAt: createTime ?? .now,
            remoteId: name,
            url: url(for: host)
        )
    }
}

extension MemosV1Visibility {
    public init(memoVisibility: MemoVisibility) {
        switch memoVisibility {
        case .direct:
            self = .PRIVATE
        case .local:
            self = .PROTECTED
        case .private:
            self = .PRIVATE
        case .public:
            self = .PUBLIC
        case .unlisted:
            self = .PUBLIC
        }
    }
}

extension MemosV1Visibility {
    func toMemoVisibility() -> MemoVisibility {
        switch self {
        case .PUBLIC:
            return .public
        case .PROTECTED:
            return .local
        case .PRIVATE:
            return .private
        default:
            return .private
        }
    }
}
