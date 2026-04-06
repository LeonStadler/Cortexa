import SwiftUI

/// Design-Helfer für macOS 26+ Liquid Glass mit Fallback für ältere Systeme (vgl. [Applying Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)).
enum MacNativeDesign {
    static let settingsFormCornerRadius: CGFloat = 14
    static let menuBarPrimaryCornerRadius: CGFloat = 12
    static let settingsTooltipCornerRadius: CGFloat = 12

    /// Einstellungen `NavigationSplitView`: Sidebar min/ideal/max und abgeleitete Fenster-Mindestbreite.
    enum SettingsSplitView {
        /// Nicht schmaler: sonst kollabiert die Spalte leicht und wirkt „weg“.
        static let sidebarMinWidth: CGFloat = 320
        static let sidebarIdealWidth: CGFloat = 320
        static let sidebarMaxWidth: CGFloat = 440
        static let detailMinWidth: CGFloat = 560
        static var windowMinWidth: CGFloat { sidebarMaxWidth + detailMinWidth }
    }
}

extension View {
    /// Primäre Menüleisten-Aktion: Liquid Glass auf macOS 26+, sonst Material.
    @ViewBuilder
    func menuBarPrimaryActionChrome(
        cornerRadius: CGFloat = MacNativeDesign.menuBarPrimaryCornerRadius
    )
        -> some View
    {
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
    }

    /// Kartenhintergrund für Einstellungsformulare.
    @ViewBuilder
    func settingsFormSurface(cornerRadius: CGFloat = MacNativeDesign.settingsFormCornerRadius)
        -> some View
    {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    /// Einheitliche `Picker`-Darstellung in Einstellungsformularen: macOS 26+ nutzt System-`.menu`-Chrome.
    @ViewBuilder
    func wisprSettingsPickerStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.pickerStyle(.menu)
        } else {
            self
        }
    }

    /// Primäre Aktion (Aktivieren, Installieren, Hinzufügen, hervorgehobene Links).
    @ViewBuilder
    func wisprPrimaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Standard-Aktionen in Formularen und Karten.
    @ViewBuilder
    func wisprSecondaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Zerstörerisch / Entfernen — immer mit `Button(role: .destructive)` kombinieren.
    @ViewBuilder
    func wisprDestructiveButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Kompakte Zeilenaktionen (Listen, Tabellen).
    @ViewBuilder
    func wisprInlineListButtonStyle() -> some View {
        self.buttonStyle(.borderless)
    }

    /// Wertespalte in `Form`/`LabeledContent`: Menüs/Picker wie in den Systemeinstellungen rechts ausrichten.
    func settingsFormValueTrailing(minWidth: CGFloat) -> some View {
        self.frame(minWidth: minWidth)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// `.menu`-Picker: volle Wertespalte nutzen, Menü-Button wirklich rechts (nicht nur `frame` am Control).
    func settingsFormMenuPickerSlot(minWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            self.fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: minWidth)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// Inhalt von Hilfe-Popovers (Einstellungen).
    @ViewBuilder
    func settingsTooltipPanelBackground(
        cornerRadius: CGFloat = MacNativeDesign.settingsTooltipCornerRadius
    ) -> some View {
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
    }
}

/// Mehrere `.glass`-Buttons in einem Raster: ein gemeinsamer Container (Apple-Empfehlung zu Performance/Morphing).
struct WisprGroupedGlassEffectContainer<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}
