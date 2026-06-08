//
//  SettingsView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//

import SwiftUI

enum Themes: String, CaseIterable{
    case Light = "Light"
    case Dark = "Dark"
    case System = "System"
}

struct SettingsView: View {
    @AppStorage("theme")
    var themes: Themes = .System
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $themes) {
                    Text("I Don't Care Just Follow System").tag(Themes.System)
                    Text("Lights On!").tag(Themes.Light)
                    Text("Lights Off!").tag(Themes.Dark)
                }
            }
            
            Section("About") {
                HStack {
                    Text("App Name")
                    Spacer()
                    Text("Watch Ur Time")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Version")
                    Spacer()
                    Text("Dev 0.67")
                        .foregroundStyle(.secondary)
                }
            }
        }.preferredColorScheme(
            {
                () in
                switch themes {
                case .Dark:
                    return .dark
                case .Light:
                    return .light
                case .System:
                    return .light
                }
            }()
        )
    }
}

#Preview {
    SettingsView()
}
