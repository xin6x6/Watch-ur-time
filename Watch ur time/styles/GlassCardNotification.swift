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
    var notificationTime: String
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(className)
                            .font(.system(size: 20, weight: .bold))
                        Text(room)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(startTime) - \(endTime)")
                        .font(.system(size: 16, weight: .bold))
                }

                HStack(spacing: 6) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 14, weight: .semibold))
                    Text(notificationTime)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }
}

#Preview {
    GlassCardNotification(
        className: "class",
        room: "room",
        startTime: "start",
        endTime: "end",
        notificationTime: "07:58"
    )
}
