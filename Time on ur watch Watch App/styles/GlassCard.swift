//
//  GlassCardView.swift
//  Watch ur time
//
//  Created by Ng1nx on 6/8/26.
//
import CoreText
import SwiftUI

enum WatchAppFontOption: String, Codable, CaseIterable, Identifiable {
    case apple
    case jetBrainsMono

    var id: String { rawValue }
}

private enum WatchJetBrainsMonoFontFace {
    static let regular = "JetBrainsMono-Regular"
    static let medium = "JetBrainsMono-Medium"
    static let semibold = "JetBrainsMono-SemiBold"
    static let bold = "JetBrainsMono-Bold"
    static let extraBold = "JetBrainsMono-ExtraBold"
    static let light = "JetBrainsMono-Light"
    static let extraLight = "JetBrainsMono-ExtraLight"
    static let thin = "JetBrainsMono-Thin"
}

private struct WatchAppFontOptionKey: EnvironmentKey {
    static let defaultValue: WatchAppFontOption = .apple
}

extension EnvironmentValues {
    var watchAppFontOption: WatchAppFontOption {
        get { self[WatchAppFontOptionKey.self] }
        set { self[WatchAppFontOptionKey.self] = newValue }
    }
}

enum WatchAppFontCatalog {
    private static var hasRegisteredBundledFonts = false
    private static let jetBrainsMonoSizeMultiplier: CGFloat = 1.08

    static var isJetBrainsMonoAvailable: Bool {
        registerBundledFontsIfNeeded()
        let names = CTFontManagerCopyAvailablePostScriptNames() as? [String] ?? []
        return names.contains(WatchJetBrainsMonoFontFace.regular)
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
        option: WatchAppFontOption
    ) -> Font {
        registerBundledFontsIfNeeded()
        let effectiveOption: WatchAppFontOption = option == .jetBrainsMono && !isJetBrainsMonoAvailable ? .apple : option
        let resolvedWeight = resolvedSwiftUIWeight(
            requested: weight,
            textStyle: textStyle,
            option: effectiveOption
        )

        switch effectiveOption {
        case .apple:
            let base = Font.system(textStyle, design: .default)
            return resolvedWeight.map { base.weight($0) } ?? base
        case .jetBrainsMono:
            let base = Font.custom(
                jetBrainsMonoPostScriptName(for: resolvedWeight),
                size: adjustedSize(baseSize(for: textStyle)),
                relativeTo: textStyle
            )
            return resolvedWeight.map { base.weight($0) } ?? base
        }
    }

    static func font(
        size: CGFloat,
        weight: Font.Weight? = nil,
        option: WatchAppFontOption
    ) -> Font {
        registerBundledFontsIfNeeded()
        let effectiveOption: WatchAppFontOption = option == .jetBrainsMono && !isJetBrainsMonoAvailable ? .apple : option
        let resolvedWeight = resolvedSizedSwiftUIWeight(requested: weight, option: effectiveOption)

        switch effectiveOption {
        case .apple:
            return .system(size: size, weight: resolvedWeight ?? .regular, design: .default)
        case .jetBrainsMono:
            let base = Font.custom(
                jetBrainsMonoPostScriptName(for: resolvedWeight),
                size: adjustedSize(size)
            )
            return resolvedWeight.map { base.weight($0) } ?? base
        }
    }

    private static func baseSize(for textStyle: Font.TextStyle) -> CGFloat {
        switch textStyle {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .body: return 17
        case .callout: return 16
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }

    private static func adjustedSize(_ size: CGFloat) -> CGFloat {
        size * jetBrainsMonoSizeMultiplier
    }

    private static func jetBrainsMonoPostScriptName(for weight: Font.Weight?) -> String {
        switch weight {
        case .some(.black), .some(.heavy):
            return WatchJetBrainsMonoFontFace.extraBold
        case .some(.bold):
            return WatchJetBrainsMonoFontFace.bold
        case .some(.semibold):
            return WatchJetBrainsMonoFontFace.semibold
        case .some(.medium):
            return WatchJetBrainsMonoFontFace.medium
        case .some(.light):
            return WatchJetBrainsMonoFontFace.light
        case .some(.thin):
            return WatchJetBrainsMonoFontFace.thin
        case .some(.ultraLight):
            return WatchJetBrainsMonoFontFace.extraLight
        default:
            return WatchJetBrainsMonoFontFace.regular
        }
    }

    private static func resolvedSwiftUIWeight(
        requested: Font.Weight?,
        textStyle: Font.TextStyle,
        option: WatchAppFontOption
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
        option: WatchAppFontOption
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
}

private struct WatchAppTextStyleModifier: ViewModifier {
    @Environment(\.watchAppFontOption) private var watchAppFontOption

    let textStyle: Font.TextStyle
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(
            WatchAppFontCatalog.font(
                textStyle,
                weight: weight,
                option: watchAppFontOption
            )
        )
    }
}

private struct WatchAppSizedFontModifier: ViewModifier {
    @Environment(\.watchAppFontOption) private var watchAppFontOption

    let size: CGFloat
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(
            WatchAppFontCatalog.font(
                size: size,
                weight: weight,
                option: watchAppFontOption
            )
        )
    }
}

private struct WatchAppDefaultFontModifier: ViewModifier {
    @Environment(\.watchAppFontOption) private var watchAppFontOption

    func body(content: Content) -> some View {
        content.font(WatchAppFontCatalog.font(.body, option: watchAppFontOption))
    }
}

extension View {
    func watchAppDefaultFont() -> some View {
        modifier(WatchAppDefaultFontModifier())
    }

    func watchAppFont(_ textStyle: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(WatchAppTextStyleModifier(textStyle: textStyle, weight: weight))
    }

    func watchAppFont(size: CGFloat, weight: Font.Weight? = nil) -> some View {
        modifier(WatchAppSizedFontModifier(size: size, weight: weight))
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .compatibleGlassSurface(cornerRadius: 30)
            .padding(.horizontal)
    }
}

extension View {
    @ViewBuilder
    func compatibleGlassSurface(
        cornerRadius: CGFloat,
        tint: Color? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(watchOS 26.0, *) {
            if let tint {
                self
                    .background(tint.opacity(0.16), in: shape)
                    .glassEffect(in: shape)
            } else {
                self.glassEffect(in: shape)
            }
        } else {
            self
                .background {
                    shape.fill(.ultraThinMaterial)

                    if let tint {
                        shape.fill(tint.opacity(0.16))
                    }
                }
                .overlay {
                    shape.stroke(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        }
    }
}
