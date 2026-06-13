//
//  GlassCardNotification.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct GlassCardNotification: View {
    var className: String
    var room: String
    var startTime: String
    var endTime: String
    
    var body: some View {
        GlassCard {
            HStack(spacing: 100) {
                Text("\(className)\n\(room)")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 19))
                    .bold(true)
                    .foregroundColor(.black)
                
                Text("\(startTime) - \(endTime)")
                    .font(.system(size: 19))
                    .bold(true)
                    .foregroundColor(.black)
            }.padding(10)
        }
    }
}

#Preview {
    GlassCardNotification(className: "class", room: "room", startTime: "start", endTime: "end")
}

