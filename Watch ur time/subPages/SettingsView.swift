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
    
        /// The content and layout of the Settings view.
        ///
        /// This body property defines the main user interface for the settings, structured as a `Form`
        /// with two sections:
        /// - "Appearance": Presents a `Picker` that allows users to choose between System, Light, and Dark themes.
        ///   The selected value is stored with `@AppStorage("theme")` and updates the app's color scheme accordingly.
        /// - "About": Displays app information such as name and version.
        ///
        /// The overall form adapts its color scheme based on the currently selected theme.
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
                    return nil
                }
            }()
        )
    }
}


#Preview {
    SettingsView()
}
