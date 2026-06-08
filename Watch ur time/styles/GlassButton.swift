//
//  GlassButton.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI
struct GlassButton: View {
    var img: String
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            
            Image(systemName: img)
            
                .font(.title)
            
        }
        
        .buttonStyle(.glass)
        
        .buttonBorderShape(.circle)
    }
}
