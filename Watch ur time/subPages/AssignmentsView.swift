//
//  AssignmentsView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct AssignmentsView: View {
    @State var show: String = "All"
    
    var body: some View {
        VStack {
            Title(text: "Assignments")
            
            GlassCard {
                HStack {
                    Picker ("Show: ", selection: $show) {
                        Text("All").tag(".all")
                        Text("Subject 1 Only").tag(".subject1")
                        Text("Subject 2 Only").tag(".subject2")
                        Text("Subject 3 Only").tag(".subject3")
                        Text("Subject 4 Only").tag(".subject4")
                    }
                    Spacer()
                    GlassButton(img: "chevron.left") {
                        // previous
                    }
                    GlassButton(img: "chevron.right") {
                        // later
                    }
                }.padding(.bottom, 15)

                
            }
        }
    }
}

#Preview {
    AssignmentsView()
}
