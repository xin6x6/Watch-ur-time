//
//  AppFont.swift
//  Watch ur time
//
//  Created by Ng1nx on 7/2/26.
//

import SwiftUI
import CoreText
import UIKit

enum AppFontOption: String, CaseIterable, Identifiable {
    case apple
    case jetBrainsMono

    static let storageKey = "app_font_option"
    static let jetBrainsMonoPostScriptName = "JetBrainsMono-Regular"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple:
            return AppLocalizer.localized("Apple")
        case .jetBrainsMono:
            return AppLocalizer.localized("JetBrains Mono")
        }
    }
}

private enum JetBrainsMonoFontFace {
    static let regular = "JetBrainsMono-Regular"
    static let medium = "JetBrainsMono-Medium"
    static let semibold = "JetBrainsMono-SemiBold"
    static let bold = "JetBrainsMono-Bold"
    static let extraBold = "JetBrainsMono-ExtraBold"
    static let light = "JetBrainsMono-Light"
    static let extraLight = "JetBrainsMono-ExtraLight"
    static let thin = "JetBrainsMono-Thin"
}

private struct AppFontOptionKey: EnvironmentKey {
    static let defaultValue: AppFontOption = .apple
}

extension EnvironmentValues {
    var appFontOption: AppFontOption {
        get { self[AppFontOptionKey.self] }
        set { self[AppFontOptionKey.self] = newValue }
    }
}

enum AppFontCatalog {
    private static var hasRegisteredBundledFonts = false
    private static let jetBrainsMonoSizeMultiplier: CGFloat = 1.08

    static var isJetBrainsMonoAvailable: Bool {
        registerBundledFontsIfNeeded()
        return UIFont(name: JetBrainsMonoFontFace.regular, size: 17) != nil
    }

    static func registerBundledFontsIfNeeded() {
        guard !hasRegisteredBundledFonts else { 
            return
        }

        hasRegisteredBundledFonts = true

        let fontURLs = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [])

        for url in fontURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func font(
        _ textStyle: Font.TextStyle,
        weight: Font.Weight? = nil,
        option: AppFontOption
    ) -> Font {
        registerBundledFontsIfNeeded()
        let effectiveOption: AppFontOption = option == .jetBrainsMono && !isJetBrainsMonoAvailable ? .apple : option
        let resolvedWeight = resolvedSwiftUIWeight(
            requested: weight,
            textStyle: textStyle,
            option: effectiveOption
        )
        let baseFont: Font

        switch effectiveOption {
        case .apple:
            baseFont = .system(textStyle, design: .default)
        case .jetBrainsMono:
            let pointSize = adjustedSize(
                UIFont.preferredFont(forTextStyle: textStyle.uiKitTextStyle).pointSize,
                option: effectiveOption
            )
            baseFont = .custom(
                jetBrainsMonoPostScriptName(for: resolvedWeight),
                size: pointSize,
                relativeTo: textStyle
            )
        }

        guard let resolvedWeight else {
            return baseFont
        }

        return baseFont.weight(resolvedWeight)
    }

    static func font(
        size: CGFloat,
        weight: Font.Weight? = nil,
        option: AppFontOption
    ) -> Font {
        registerBundledFontsIfNeeded()
        let effectiveOption: AppFontOption = option == .jetBrainsMono && !isJetBrainsMonoAvailable ? .apple : option
        let resolvedWeight = resolvedSizedSwiftUIWeight(
            requested: weight,
            option: effectiveOption
        )
        let baseFont: Font

        switch effectiveOption {
        case .apple:
            baseFont = .system(size: size, weight: resolvedWeight ?? .regular, design: .default)
        case .jetBrainsMono:
            baseFont = .custom(
                jetBrainsMonoPostScriptName(for: resolvedWeight),
                size: adjustedSize(size, option: effectiveOption)
            )
        }

        guard let resolvedWeight, effectiveOption == .jetBrainsMono else {
            return baseFont
        }

        return baseFont.weight(resolvedWeight)
    }

    static func uiFont(
        textStyle: UIFont.TextStyle,
        weight: UIFont.Weight? = nil,
        option: AppFontOption,
        sizeScale: CGFloat = 1
    ) -> UIFont {
        registerBundledFontsIfNeeded()
        let effectiveOption: AppFontOption = option == .jetBrainsMono && !isJetBrainsMonoAvailable ? .apple : option

        switch effectiveOption {
        case .apple:
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
            let basePointSize = descriptor.pointSize
            return .systemFont(ofSize: basePointSize * sizeScale, weight: weight ?? .regular)
        case .jetBrainsMono:
            let resolvedWeight = resolvedUIKitWeight(requested: weight, textStyle: textStyle)
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
            let pointSize = adjustedSize(descriptor.pointSize * sizeScale, option: effectiveOption)
            let base = UIFont(name: jetBrainsMonoPostScriptName(for: resolvedWeight.swiftUIWeight), size: pointSize)
                ?? .monospacedSystemFont(ofSize: pointSize, weight: resolvedWeight)
            return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
        }
    }

    private static func jetBrainsMonoPostScriptName(for weight: Font.Weight?) -> String {
        switch weight {
        case .some(.black), .some(.heavy):
            return JetBrainsMonoFontFace.extraBold
        case .some(.bold):
            return JetBrainsMonoFontFace.bold
        case .some(.semibold):
            return JetBrainsMonoFontFace.semibold
        case .some(.medium):
            return JetBrainsMonoFontFace.medium
        case .some(.light):
            return JetBrainsMonoFontFace.light
        case .some(.thin):
            return JetBrainsMonoFontFace.thin
        case .some(.ultraLight):
            return JetBrainsMonoFontFace.extraLight
        default:
            return JetBrainsMonoFontFace.regular
        }
    }

    private static func adjustedSize(_ size: CGFloat, option: AppFontOption) -> CGFloat {
        option == .jetBrainsMono ? size * jetBrainsMonoSizeMultiplier : size
    }

    private static func resolvedSwiftUIWeight(
        requested: Font.Weight?,
        textStyle: Font.TextStyle,
        option: AppFontOption
    ) -> Font.Weight? {
        switch option {
        case .apple:
            return requested
        case .jetBrainsMono:
            return requested ?? semanticSwiftUIWeight(for: textStyle)
        }
    }

    private static func resolvedSizedSwiftUIWeight(
        requested: Font.Weight?,
        option: AppFontOption
    ) -> Font.Weight? {
        switch option {
        case .apple:
            return requested
        case .jetBrainsMono:
            return requested ?? .medium
        }
    }

    private static func semanticSwiftUIWeight(for textStyle: Font.TextStyle) -> Font.Weight {
        switch textStyle {
        case .headline:
            return .bold
        case .subheadline, .body, .callout, .footnote:
            return .medium
        case .caption, .caption2:
            return .semibold
        default:
            return .medium
        }
    }

    private static func resolvedUIKitWeight(
        requested: UIFont.Weight?,
        textStyle: UIFont.TextStyle
    ) -> UIFont.Weight {
        if let requested {
            return requested
        }

        switch textStyle {
        case .headline:
            return .bold
        case .subheadline, .body, .callout, .footnote:
            return .medium
        case .caption1, .caption2:
            return .semibold
        default:
            return .medium
        }
    }
}

extension UIFont.Weight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        default:
            return .regular
        }
    }
}

enum AppControlFontStyler {
    static func apply(option: AppFontOption) {
        let segmentedNormal = AppFontCatalog.uiFont(
            textStyle: .footnote,
            weight: .medium,
            option: option,
            sizeScale: 0.96
        )
        let segmentedSelected = AppFontCatalog.uiFont(
            textStyle: .footnote,
            weight: .bold,
            option: option,
            sizeScale: 0.96
        )

        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: segmentedNormal],
            for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: segmentedSelected],
            for: .selected
        )

        let tabNormal = AppFontCatalog.uiFont(
            textStyle: .caption2,
            weight: .medium,
            option: option,
            sizeScale: 0.9
        )
        let tabSelected = AppFontCatalog.uiFont(
            textStyle: .caption2,
            weight: .bold,
            option: option,
            sizeScale: 0.9
        )

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.font: tabNormal, .kern: -0.2]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.font: tabSelected, .kern: -0.2]
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.font: tabNormal, .kern: -0.2]
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.font: tabSelected, .kern: -0.2]
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.font: tabNormal, .kern: -0.2]
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.font: tabSelected, .kern: -0.2]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().itemPositioning = .fill

        let navInline = AppFontCatalog.uiFont(
            textStyle: .headline,
            weight: .bold,
            option: option,
            sizeScale: 1
        )
        let navLarge = AppFontCatalog.uiFont(
            textStyle: .largeTitle,
            weight: .bold,
            option: option,
            sizeScale: 1
        )
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [.font: navInline]
        navAppearance.largeTitleTextAttributes = [.font: navLarge]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        let barButtonFont = AppFontCatalog.uiFont(
            textStyle: .body,
            weight: .semibold,
            option: option,
            sizeScale: 1
        )
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: barButtonFont],
            for: .normal
        )
    }
}

private struct AppTextStyleModifier: ViewModifier {
    @Environment(\.appFontOption) private var appFontOption

    let textStyle: Font.TextStyle
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(
            AppFontCatalog.font(
                textStyle,
                weight: weight,
                option: appFontOption
            )
        )
    }
}

private struct AppSizedFontModifier: ViewModifier {
    @Environment(\.appFontOption) private var appFontOption

    let size: CGFloat
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(
            AppFontCatalog.font(
                size: size,
                weight: weight,
                option: appFontOption
            )
        )
    }
}

private extension Font.TextStyle {
    var uiKitTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title1
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .body:
            return .body
        case .callout:
            return .callout
        case .footnote:
            return .footnote
        case .caption:
            return .caption1
        case .caption2:
            return .caption2
        @unknown default:
            return .body
        }
    }
}

extension View {
    func appDefaultFont() -> some View {
        modifier(AppDefaultFontModifier())
    }

    func appFont(_ textStyle: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(AppTextStyleModifier(textStyle: textStyle, weight: weight))
    }

    func appFont(size: CGFloat, weight: Font.Weight? = nil) -> some View {
        modifier(AppSizedFontModifier(size: size, weight: weight))
    }
}

private struct AppDefaultFontModifier: ViewModifier {
    @Environment(\.appFontOption) private var appFontOption

    func body(content: Content) -> some View {
        content.font(AppFontCatalog.font(.body, option: appFontOption))
    }
}
