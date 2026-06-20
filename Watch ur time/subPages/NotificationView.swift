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
        NavigationStack {
            VStack (spacing: 12) {
                Title(text: dayToString[day]!)
                
                NavigationLink(destination: AdjustNotificationView(day: day)) {
                    GlassCardNotification(className: "Class", room: "Room", startTime: "Start", endTime: "End")
                }
                NavigationLink(destination: AdjustNotificationView(day: day)) {
                    GlassCardNotification(className: "Class", room: "Room", startTime: "Start", endTime: "End")
                }
                NavigationLink(destination: AdjustNotificationView(day: day)) {
                    GlassCardNotification(className: "Class", room: "Room", startTime: "Start", endTime: "End")
                }
                NavigationLink(destination: AdjustNotificationView(day: day)) {
                    GlassCardNotification(className: "Class", room: "Room", startTime: "Start", endTime: "End")
                }
            }.simultaneousGesture(TapGesture().onEnded{ _ in
                UIImpactFeedbackGenerator(style: .heavy)
                    .impactOccurred()
            })
        }.tint(.primary)
    }
}


struct AdjustNotificationView: View {
    @State var day: Int
    
    @State private var atSelection = 0
    @State private var advanceTime = 5
    let atOptions = ["Class begins", "Class ends", "Both"]
    let advanceOptions = Array(0...60)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
                // Header
            HStack {
                Text("Adjust notification")
                    .font(.title2.bold())
            }
            .padding(.bottom, 8)
            
                // Section: At
            VStack(alignment: .leading, spacing: 12) {
                Text("At")
                    .font(.headline)
                Picker("At", selection: $atSelection) {
                    ForEach(0..<atOptions.count, id: \.self) { idx in
                        Text(atOptions[idx])
                    }
                }
                .pickerStyle(.segmented)
            }
            
            /**
             Picker("Name", selection: $selections){
             tags...
             }
             */
            
                // Section: In advance for
            VStack(alignment: .leading, spacing: 12) {
                Text("In advance for")
                    .font(.headline)
                Picker("In advance for", selection: $advanceTime) {
                    ForEach(advanceOptions, id: \.self) { minute in
                        Text(minute == 0 ? "On time" : "\(minute) mins")
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }
            Spacer()
        }
        .padding()
    }
}



#Preview {
    NotificationView(day: .constant(1))
}
