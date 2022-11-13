//
//  Attachment.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/14.
//

import SwiftUI

struct Attachment: View {
    let resource: Resource
    @State var showingAttachment = false
    @EnvironmentObject private var memosManager: MemosManager
    
    var body: some View {
        Button {
            showingAttachment = true
        } label: {
            HStack {
                Image(systemName: "paperclip")
                Text(resource.filename)
            }
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding([.top, .bottom], 5)
        .sheet(isPresented: $showingAttachment) {
            if let hostURL = memosManager.hostURL {
                SafariView(url: hostURL.appendingPathComponent(resource.path()))
            }
        }
    }
}

struct Attachment_Previews: PreviewProvider {
    static var previews: some View {
        Attachment(resource: Resource(id: 0, createdTs: Date(), creatorId: 0, filename: "test.yml", size: 0, type: "application/x-yaml", updatedTs: Date()))
            .environmentObject(MemosManager())
    }
}
