import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case leisidongTranslation

    static let storageKey = "app_language"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return AppLocalizer.localized("Follow System")
        case .english:
            return AppLocalizer.localized("English")
        case .simplifiedChinese:
            return AppLocalizer.localized("Simplified Chinese")
        case .leisidongTranslation:
            return "雷石东翻译"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .leisidongTranslation:
            return Locale(identifier: "zh-Hans")
        }
    }

    fileprivate var bundleLanguageCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .leisidongTranslation:
            return "leisidong"
        }
    }

    fileprivate var fallbackLanguage: AppLanguage? {
        switch self {
        case .leisidongTranslation:
            return .simplifiedChinese
        case .system, .english, .simplifiedChinese:
            return nil
        }
    }
}

enum AppLocalizer {
    static func selectedLanguage() -> AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? "")
            ?? .system
    }

    static func localized(_ key: String, language: AppLanguage? = nil) -> String {
        let resolvedLanguage = language ?? selectedLanguage()

        guard let bundleLanguageCode = resolvedLanguage.bundleLanguageCode,
              let path = Bundle.main.path(forResource: bundleLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            if let fallbackLanguage = resolvedLanguage.fallbackLanguage {
                return localized(key, language: fallbackLanguage)
            }
            return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        }

        let localizedValue = bundle.localizedString(forKey: key, value: nil, table: nil)

        if localizedValue != key {
            return localizedValue
        }

        if let fallbackLanguage = resolvedLanguage.fallbackLanguage {
            return localized(key, language: fallbackLanguage)
        }

        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, locale: selectedLanguage().locale, arguments: arguments)
    }

    static func minuteSummary(_ minutes: Int) -> String {
        minutes == 0 ? localized("On time") : format("%d mins", minutes)
    }
}
