//
//  SettingsView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

struct SettingsView: View {
    @State var darkModeEnabled: Bool = false
    
    var body: some View {
        Form {
            Section("General") {
                
                Toggle("Dark Mode", isOn: $darkModeEnabled)
                
            }
            
            Section("About") {
                HStack {
                    Text("App Name")
                    Spacer()
                    Text("Watch ur time")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
