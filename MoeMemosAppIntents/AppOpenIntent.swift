//
//  OpenAppIntent.swift
//  MoeMemos
//
//  Created by Mudkip on 2024/11/20.
//

import AppIntents
import Env

struct AppOpenIntent: AppIntent {
    static let title: LocalizedStringResource = "Launch Moe Memos"
     
    static let openAppWhenRun: Bool = true
    
    @Dependency
    var appPath: AppPath
    
    func perform() async throws -> some IntentResult {
        appPath.presentedSheet = .newMemo
        return .result()
    }
}
