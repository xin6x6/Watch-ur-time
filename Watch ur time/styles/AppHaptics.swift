//
//  AppHaptics.swift
//  Watch ur time
//
//  Created By Ng1nx on 7/5/26.
//

import Foundation
import UIKit

enum AppHapticStrength: String, CaseIterable, Identifiable {
    case weak
    case medium
    case strong

    static let storageKey = "global_haptics_strength"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weak:
            return AppLocalizer.localized("Weak")
        case .medium:
            return AppLocalizer.localized("Medium")
        case .strong:
            return AppLocalizer.localized("Strong")
        }
    }
}

enum AppHapticStyle {
    case tap
    case selection
    case success
    case warning
    case error
}

enum AppHaptics {
    static let enabledKey = "global_haptics_enabled"
    static let strengthKey = AppHapticStrength.storageKey

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var strength: AppHapticStrength {
        guard let rawValue = UserDefaults.standard.string(forKey: strengthKey),
              let strength = AppHapticStrength(rawValue: rawValue) else {
            return .medium
        }
        return strength
    }

    static func trigger(_ style: AppHapticStyle) {
        guard isEnabled else {
            return
        }

        switch style {
        case .tap:
            let generator = UIImpactFeedbackGenerator(style: impactStyle(for: .tap))
            generator.prepare()
            generator.impactOccurred(intensity: impactIntensity(for: .tap))
        case .selection:
            let generator = UIImpactFeedbackGenerator(style: impactStyle(for: .selection))
            generator.prepare()
            generator.impactOccurred(intensity: impactIntensity(for: .selection))
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            triggerSupplementalImpact(for: .success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
            triggerSupplementalImpact(for: .warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
            triggerSupplementalImpact(for: .error)
        }
    }

    private static func impactStyle(for style: AppHapticStyle) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch (style, strength) {
        case (.tap, .weak):
            return .light
        case (.tap, .medium):
            return .medium
        case (.tap, .strong):
            return .heavy
        case (.selection, .weak):
            return .light
        case (.selection, .medium):
            return .medium
        case (.selection, .strong):
            return .rigid
        case (.success, .weak), (.warning, .weak), (.error, .weak):
            return .light
        case (.success, .medium), (.warning, .medium), (.error, .medium):
            return .medium
        case (.success, .strong), (.warning, .strong), (.error, .strong):
            return .heavy
        }
    }

    private static func impactIntensity(for style: AppHapticStyle) -> CGFloat {
        switch (style, strength) {
        case (.tap, .weak):
            return 0.45
        case (.tap, .medium):
            return 0.8
        case (.tap, .strong):
            return 1.0
        case (.selection, .weak):
            return 0.35
        case (.selection, .medium):
            return 0.7
        case (.selection, .strong):
            return 1.0
        case (.success, .weak), (.warning, .weak), (.error, .weak):
            return 0.45
        case (.success, .medium), (.warning, .medium), (.error, .medium):
            return 0.75
        case (.success, .strong), (.warning, .strong), (.error, .strong):
            return 1.0
        }
    }

    private static func triggerSupplementalImpact(for style: AppHapticStyle) {
        guard strength != .weak else {
            return
        }

        let generator = UIImpactFeedbackGenerator(style: impactStyle(for: style))
        generator.prepare()
        generator.impactOccurred(intensity: impactIntensity(for: style))

        if strength == .strong {
            let secondGenerator = UIImpactFeedbackGenerator(style: .rigid)
            secondGenerator.prepare()
            secondGenerator.impactOccurred(intensity: 0.9)
        }
    }
}
