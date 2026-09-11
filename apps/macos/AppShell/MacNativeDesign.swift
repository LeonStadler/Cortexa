import SwiftUI

/// Layout- und Material-Helfer ausgerichtet an Apples [Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass),
/// [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
/// sowie dem Überblick [LiquidGlassReference](https://github.com/conorluddy/LiquidGlassReference).
enum MacNativeDesign {
    static let menuBarPrimaryCornerRadius: CGFloat = 12
    static let settingsTooltipCornerRadius: CGFloat = 12

    /// Einstellungen `NavigationSplitView`: Sidebar min/ideal/max und abgeleitete Fenster-Mindestbreite.
    enum SettingsSplitView {
        /// Native macOS source lists bleiben kompakt und lassen dem Detail genug Raum.
        static let sidebarMinWidth: CGFloat = 220
        static let sidebarIdealWidth: CGFloat = 240
        static let sidebarMaxWidth: CGFloat = 300
        static let detailMinWidth: CGFloat = 560
        static var windowMinWidth: CGFloat { sidebarMaxWidth + detailMinWidth }
    }
}

extension View {
    /// Menüleisten-Hauptaktion: „floating“-Kontrolle — `glassEffect(.regular.interactive())` auf macOS 26+,
    /// sonst `Material` ([`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))).
    @ViewBuilder
    func menuBarPrimaryActionSurface(
        cornerRadius: CGFloat = MacNativeDesign.menuBarPrimaryCornerRadius
    ) -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        #else
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        #endif
    }

    /// `.menu`-Picker in Einstellungsformularen: volle Wertespalte, Auswahl rechts (`LabeledContent`).
    func settingsFormMenuPickerSlot(minWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            self.fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: minWidth)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// Sidebar neben dem Detail: Rand-Effekt wie in Apples Split-View-Hinweisen ([`backgroundExtensionEffect()`](https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect())).
    @ViewBuilder
    func settingsSidebarBackgroundExtensionEffect() -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Kompaktes Hilfe-Popover (schwebende Kontrolle, kein scrollender Flächeninhalt).
    @ViewBuilder
    func settingsTooltipPanelBackground(
        cornerRadius: CGFloat = MacNativeDesign.settingsTooltipCornerRadius
    ) -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            self.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        #else
        self.background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        #endif
    }

    // MARK: - Liquid Glass Button Styles (`.glass` / `.glassProminent` auf macOS 26+)

    @ViewBuilder
    func liquidGlassPrimaryButtonStyle() -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
        #else
        self.buttonStyle(.borderedProminent)
        #endif
    }

    @ViewBuilder
    func liquidGlassSecondaryButtonStyle() -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
        #else
        self.buttonStyle(.bordered)
        #endif
    }

    @ViewBuilder
    func liquidGlassDestructiveButtonStyle() -> some View {
        #if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
        #else
        self.buttonStyle(.bordered)
        #endif
    }
}
