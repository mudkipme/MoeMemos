//
//  HTTP.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

private var memosJsonDecoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
}

enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
}

enum HTTPBodyEncodeMode {
    case json
    case urlencoded
    case none
    
    func contentType() -> String? {
        switch self {
        case .json:
            return "application/json"
        default:
            return nil
        }
    }
    
    func encode<T: Encodable>(_ data: T) throws -> Data? {
        switch self {
        case .urlencoded:
            let queryItems = try encodeToQueryItems(data)
            var components = URLComponents()
            components.queryItems = queryItems
            return components.percentEncodedQuery?.data(using: .utf8)
        case .json:
            return try JSONEncoder().encode(data)
        default:
            return nil
        }
    }
}

enum HTTPBodyDecodeMode {
    case json
    case none
    
    func decode<T: Decodable>(_ data: Data) throws -> T {
        switch self {
        case .json:
            return try memosJsonDecoder.decode(T.self, from: data)
        default:
            if let result = data as? T {
                return result
            }
            throw MemosError.unknown
        }
    }
}

func encodeToQueryItems<T: Encodable>(_ data: T) throws -> [URLQueryItem]? {
    let json = try JSONEncoder().encode(data)
    if let dict = try JSONSerialization.jsonObject(with: json, options: []) as? [String: Any] {
        var queryItems = [URLQueryItem]()
        for (name, value) in dict {
            queryItems.append(URLQueryItem(name: name, value: "\(value)"))
        }
        return queryItems
    }
    return nil
}
