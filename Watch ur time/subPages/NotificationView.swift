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
        }
    }
}


struct AdjustNotificationView: View {
    @State var day: Int
    
    @State private var atSelection = 0
    @State private var advanceTime = 2
    let atOptions = ["Class begins", "Class ends", "Both"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Header
            HStack {
                Text("Adjust notification")
                    .font(.title2.bold())
//                Spacer()
//                Button(action: { /* Save action */ }) {
//                    Image(systemName: "checkmark")
//                        .font(.title2.bold())
//                        .foregroundColor(.black)
//                        .padding(10)
//                        .background(.thinMaterial, in: Circle())
//                }
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
                HStack {
                    Spacer()
                    Text("\(advanceTime) mins")
                        .font(.body)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
                    Spacer()
                }
            }
            Spacer()
        }
        .padding()
    }
}



#Preview {
    NotificationView(day: .constant(1))
}
