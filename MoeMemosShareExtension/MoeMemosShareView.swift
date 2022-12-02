//
//  MoeMemosShareView.swift
//  MoeMemosShareExtension
//
//  Created by Mudkip on 2022/12/1.
//

import SwiftUI

struct MoeMemosShareView: View {
    let alertType: AlertType
    @State var isPresenting = true
    
    init(alertType: AlertType = .loading) {
        self.alertType = alertType
    }
    
    var body: some View {
        Color.clear
            .toast(isPresenting: $isPresenting, alertType: alertType)
    }
}

struct MoeMemosShareView_Previews: PreviewProvider {
    static var previews: some View {
        MoeMemosShareView()
    }
}
