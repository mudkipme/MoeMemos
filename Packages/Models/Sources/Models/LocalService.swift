//
//  LocalService.swift
//  Models
//
//  Created by Mudkip on 2025/5/6.
//

import Foundation
import SwiftData

@MainActor
public final class LocalService: RemoteService {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func memoVisibilities() -> [MemoVisibility] {
        return [.private]
    }
    
    public func listMemos() async throws -> [Memo] {
        let descriptor = FetchDescriptor<MemoModel>(
            predicate: #Predicate { $0.rowStatus == RowStatus.normal },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
        let memos = try modelContext.fetch(descriptor)
        return memos.map { self.convertToMemo($0) }
    }
    
    public func listArchivedMemos() async throws -> [Memo] {
        let descriptor = FetchDescriptor<MemoModel>(
            predicate: #Predicate { $0.rowStatus == RowStatus.archived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        let memos = try modelContext.fetch(descriptor)
        return memos.map { self.convertToMemo($0) }
    }
    
    public func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?) {
        return ([], nil)
    }
    
    public func createMemo(content: String, visibility: MemoVisibility?, resources: [Resource], tags: [String]?) async throws -> Memo {
        let memo = MemoModel(
            createdAt: .now,
            updatedAt: .now,
            content: content,
            pinned: false,
            rowStatus: .normal,
            visibility: visibility ?? .private,
            resoruces: [],
            tags: []
        )
        
        // Add resources
        let resourceModels = resources.map { resource in
            let resourceModel = ResourceModel(
                createdAt: resource.createdAt,
                updatedAt: resource.updatedAt,
                filename: resource.filename,
                size: resource.size,
                mimeType: resource.mimeType,
                url: resource.url,
                memo: memo
            )
            return resourceModel
        }
        memo.resoruces = resourceModels
        
        // Add tags
        if let tags = tags {
            memo.tags = tags.compactMap { tagName in
                let tagDescriptor = FetchDescriptor<TagModel>(
                    predicate: #Predicate { $0.name == tagName }
                )
                
                if let existingTag = try? modelContext.fetch(tagDescriptor).first {
                    return Tag(name: existingTag.name)
                } else {
                    let newTagModel = TagModel(name: tagName, memos: [memo])
                    modelContext.insert(newTagModel)
                    return Tag(name: tagName)
                }
            }
        }
        
        modelContext.insert(memo)
        try modelContext.save()
        
        return convertToMemo(memo)
    }
    
    public func updateMemo(remoteId: String, content: String?, resources: [Resource]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> Memo {
        guard let memoModel = try findMemoModel(remoteId: remoteId) else {
            throw MoeMemosError.invalidParams
        }
        
        if let content = content {
            memoModel.content = content
        }
        
        if let visibility = visibility {
            memoModel.visibility = visibility
        }
        
        if let pinned = pinned {
            memoModel.pinned = pinned
        }
        
        if let resources = resources {
            // Remove existing resources
            for resource in memoModel.resoruces {
                modelContext.delete(resource)
            }
            
            // Add new resources
            let resourceModels = resources.map { resource in
                let resourceModel = ResourceModel(
                    createdAt: resource.createdAt,
                    updatedAt: resource.updatedAt,
                    filename: resource.filename,
                    size: resource.size,
                    mimeType: resource.mimeType,
                    url: resource.url,
                    memo: memoModel
                )
                return resourceModel
            }
            memoModel.resoruces = resourceModels
        }
        
        if let tags = tags {
            // Update tags
            memoModel.tags = tags.compactMap { tagName in
                let tagDescriptor = FetchDescriptor<TagModel>(
                    predicate: #Predicate { $0.name == tagName }
                )
                
                if let existingTag = try? modelContext.fetch(tagDescriptor).first {
                    return Tag(name: existingTag.name)
                } else {
                    let newTagModel = TagModel(name: tagName, memos: [memoModel])
                    modelContext.insert(newTagModel)
                    return Tag(name: tagName)
                }
            }
        }
        
        memoModel.updatedAt = .now
        try modelContext.save()
        
        return convertToMemo(memoModel)
    }
    
    public func deleteMemo(remoteId: String) async throws {
        guard let memoModel = try findMemoModel(remoteId: remoteId) else {
            throw MoeMemosError.invalidParams
        }
        
        modelContext.delete(memoModel)
        try modelContext.save()
    }
    
    public func archiveMemo(remoteId: String) async throws {
        guard let memoModel = try findMemoModel(remoteId: remoteId) else {
            throw MoeMemosError.invalidParams
        }
        
        memoModel.rowStatus = .archived
        memoModel.updatedAt = .now
        try modelContext.save()
    }
    
    public func restoreMemo(remoteId: String) async throws {
        guard let memoModel = try findMemoModel(remoteId: remoteId) else {
            throw MoeMemosError.invalidParams
        }
        
        memoModel.rowStatus = .normal
        memoModel.updatedAt = .now
        try modelContext.save()
    }
    
    public func listTags() async throws -> [Tag] {
        let descriptor = FetchDescriptor<TagModel>()
        let tagModels = try modelContext.fetch(descriptor)
        return tagModels.map { Tag(name: $0.name) }
    }
    
    public func deleteTag(name: String) async throws {
        let tagDescriptor = FetchDescriptor<TagModel>(
            predicate: #Predicate { $0.name == name }
        )
        
        let tagModels = try modelContext.fetch(tagDescriptor)
        for tagModel in tagModels {
            modelContext.delete(tagModel)
        }
        
        try modelContext.save()
    }
    
    public func listResources() async throws -> [Resource] {
        let descriptor = FetchDescriptor<ResourceModel>()
        let resourceModels = try modelContext.fetch(descriptor)
        return resourceModels.compactMap { self.convertToResource($0) }
    }
    
    public func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource {
        // Create a local URL for the resource
       let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
       let resourcesDirectory = documentsDirectory.appendingPathComponent("resources", isDirectory: true)
       
       // Create directory if it doesn't exist
       try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
       
       let uniqueFilename = UUID().uuidString + "-" + filename
       let fileURL = resourcesDirectory.appendingPathComponent(uniqueFilename)
       
       // Save file
       try data.write(to: fileURL)
       
       var memoModel: MemoModel? = nil
       if let memoRemoteId = memoRemoteId {
           memoModel = try findMemoModel(remoteId: memoRemoteId)
       }
       
       let resourceModel = ResourceModel(
           createdAt: .now,
           updatedAt: .now,
           filename: filename,
           size: data.count,
           mimeType: type,
           url: fileURL,
           memo: memoModel,
           data: data
       )
       
       modelContext.insert(resourceModel)
       try modelContext.save()
       
       return Resource(
           filename: resourceModel.filename,
           size: resourceModel.size,
           mimeType: resourceModel.mimeType,
           createdAt: resourceModel.createdAt,
           updatedAt: resourceModel.updatedAt,
           url: resourceModel.url ?? URL(string: "file:///invalid")!
       )
    }
    
    public func deleteResource(remoteId: String) async throws {
        let descriptor = FetchDescriptor<ResourceModel>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        
        let resources = try modelContext.fetch(descriptor)
        guard let resource = resources.first else {
            throw MoeMemosError.invalidParams
        }
        
        // Delete the file if it exists
        if let url = resource.url, FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        
        modelContext.delete(resource)
        try modelContext.save()
    }
    
    public func getCurrentUser() async throws -> User {
        // For local service, return a default user
        return User(accountKey: "local", nickname: "Local User")
    }
    
    public func download(url: URL, mimeType: String?) async throws -> URL {
        // For local URLs, just return the URL
        if url.isFileURL {
            return url
        }
        
        // For remote URLs, download the file
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheDirectory = documentsDirectory.appendingPathComponent("cache", isDirectory: true)
        
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        let filename = url.lastPathComponent
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    // Helper methods
    private func findMemoModel(remoteId: String) throws -> MemoModel? {
        let descriptor = FetchDescriptor<MemoModel>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        
        return try modelContext.fetch(descriptor).first
    }
    
    
    private func convertToMemo(_ memoModel: MemoModel) -> Memo {
        let resources = memoModel.resoruces.compactMap { self.convertToResource($0) }
        
        return Memo(
            content: memoModel.content,
            pinned: memoModel.pinned,
            rowStatus: memoModel.rowStatus,
            visibility: memoModel.visibility,
            resources: resources,
            createdAt: memoModel.createdAt,
            updatedAt: memoModel.updatedAt,
            remoteId: memoModel.remoteId
        )
    }
        
    private func convertToResource(_ resourceModel: ResourceModel) -> Resource? {
        guard let url = resourceModel.url else { return nil }
        
        return Resource(
            filename: resourceModel.filename,
            size: resourceModel.size,
            mimeType: resourceModel.mimeType,
            createdAt: resourceModel.createdAt,
            updatedAt: resourceModel.updatedAt,
            remoteId: resourceModel.remoteId,
            url: url
        )
    }
}
