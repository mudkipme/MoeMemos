//
//  Types.swift
//
//
//  Created by Mudkip on 2023/11/18.
//

import Foundation
import Models

public typealias MemosV0User = Components.Schemas.User
typealias MemosV0Memo = Components.Schemas.Memo
typealias MemosV0Resource = Components.Schemas.Resource
typealias MemosV0Visibility = Components.Schemas.Visibility
public typealias MemosV0Status = Components.Schemas.SystemStatus

extension MemosV0Memo {
    var createDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdTs))
    }
    
    func toMemo(host: URL) -> Memo {
        let updatedAt: Date
        if let updatedTs = updatedTs {
            updatedAt = Date(timeIntervalSince1970: TimeInterval(updatedTs))
        } else {
            updatedAt = .now
        }
        return Memo(
            content: content,
            pinned: pinned ?? false,
            rowStatus: rowStatus == .ARCHIVED ? .archived : .normal,
            visibility: visibility?.toMemoVisibility() ?? .private,
            resources: resourceList?.map { $0.toResource(host: host) } ?? [],
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdTs)),
            updatedAt: updatedAt,
            remoteId: String(id)
        )
    }
}

extension MemosV0User {
    var defaultMemoVisibility: MemosV0Visibility {
        guard let visibilityJson = self.userSettingList?.first(where: { $0.key == "memo-visibility" })?.value?.data(using: .utf8) else { return .PRIVATE }
        do {
            return try JSONDecoder().decode(MemosV0Visibility.self, from: visibilityJson)
        } catch {
            return .PRIVATE
        }
    }
}

extension MemosV0Resource: Identifiable {
    func path() -> String {
        if let uid = uid, !uid.isEmpty {
            return "/o/r/\(uid)"
        }
        return "/o/r/\(name ?? "")"
    }
    
    func url(for hostURL: URL) -> URL {
        if let externalLink = externalLink, !externalLink.isEmpty, let url = URL(string: externalLink) {
            return url
        }
        return hostURL.appending(path: path())
    }
    
    func toResource(host: URL) -> Resource {
        let createdAt: Date
        if let createdTs = createdTs {
            createdAt = Date(timeIntervalSince1970: TimeInterval(createdTs))
        } else {
            createdAt = .now
        }
        let updatedAt: Date
        if let updatedTs = updatedTs {
            updatedAt = Date(timeIntervalSince1970: TimeInterval(updatedTs))
        } else {
            updatedAt = .now
        }
        return Resource(filename: filename, size: size ?? 0, mimeType: self._type ?? "application/octet-stream", createdAt: createdAt, updatedAt: updatedAt, remoteId: String(id), url: self.url(for: host))
    }
}

extension MemosV0Visibility {
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

extension MemosV0Visibility {
    func toMemoVisibility() -> MemoVisibility {
        switch self {
        case .PUBLIC:
            return .public
        case .PROTECTED:
            return .local
        case .PRIVATE:
            return .private
        }
    }
}
