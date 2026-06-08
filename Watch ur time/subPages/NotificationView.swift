//
//  NotificationView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//
import SwiftUI

var dayToString = [1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday", 5: "Friday"]

struct NotificationView: View {
    @Binding var day: Int
    
    var body: some View {
        VStack (spacing: 12) {
            Title(text: dayToString[day]!)
            
            GlassCardNotification(className: "Class", room: "Room", startTime: "Start", endTime: "End")
            GlassCardNotification(className: "Class", room: "Room", startTime: "Start", endTime: "End")
            GlassCardNotification(className: "Class", room: "Room", startTime: "Start", endTime: "End")
            GlassCardNotification(className: "Class", room: "Room", startTime: "Start", endTime: "End")
        }.simultaneousGesture(TapGesture().onEnded{ _ in
            UIImpactFeedbackGenerator(style: .heavy)
                .impactOccurred()
        })
    }
}

#Preview {
    NotificationView(day: .constant(1))
}
