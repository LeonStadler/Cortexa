import AIProcessingCore
import ASRCore
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: MacAppState
    @EnvironmentObject private var updaterController: SparkleUpdaterController
    @AppStorage("wispr.uiLanguage") private var uiLanguageRaw: String = AppLanguage.system.rawValue

    private var storedLanguage: AppLanguage {
        AppLanguage(rawValue: uiLanguageRaw) ?? .system
    }

    private var effectiveLanguage: AppLanguage {
        storedLanguage.contentLanguage
    }

    private func text(_ german: String, _ english: String) -> String {
        storedLanguage.text(german, english)
    }

    private var showsUpdateMenuItem: Bool {
        updaterController.state.allowsManualCheck
    }

    private var showsStatusHeader: Bool {
        appState.isSessionActive || appState.hasPermissionProblems
            || appState.recordingStatus == "Error"
    }

    private var primaryActionTitle: String {
        appState.isSessionActive
            ? text("Diktat stoppen", "Stop Dictation")
            : text("Diktat starten", "Start Dictation")
    }

    private var hasQuickSettingsAIModels: Bool {
        !appState.availableQuickSettingsAIModels.isEmpty
    }

    /// Kompakt: nur bei kopierbarem Text. Normal: bei Text oder gespeichertem Verlauf (Menü/Liste).
    private var menuBarShowsDictationHistorySection: Bool {
        if appState.compactMenuBarDesign {
            return !appState.latestDictationText.isEmpty
        }
        return !appState.latestDictationText.isEmpty || !appState.transcriptHistory.isEmpty
    }

    private var visibleMenuBarLanguages: [DictationLanguage] {
        let configured = appState.visibleMenuBarLanguages.compactMap(
            DictationLanguage.init(rawValue:))
        return [.auto] + configured
    }

    private func aiProviderMenuSectionTitle(for model: AIModelDescriptor) -> String {
        if model.providerID == "apple.foundation" {
            return text("Apple", "Apple")
        }
        if let remote = appState.remoteProviders.first(where: { $0.id == model.providerID }) {
            return remote.displayName
        }
        return model.providerID
    }

    /// Zeilenbezeichnung ohne vorangestellten Anbieter (z. B. nur „deepseek-r1:1.8b“, nicht „Ollama - …“).
    private func aiModelMenuRowTitle(for model: AIModelDescriptor) -> String {
        if model.providerKind == .remoteAPI,
            let remote = appState.remoteProviders.first(where: { $0.id == model.providerID })
        {
            let prefix = remote.displayName + " - "
            if model.displayName.hasPrefix(prefix) {
                return String(model.displayName.dropFirst(prefix.count))
            }
        }
        return model.displayName
    }

    private var aiModelsGroupedForMenu: [(section: String, models: [AIModelDescriptor])] {
        let models = appState.visibleAIModels
        guard !models.isEmpty else { return [] }
        let grouped = Dictionary(grouping: models) { aiProviderMenuSectionTitle(for: $0) }
        let appleHeading = text("Apple", "Apple")
        let keys = grouped.keys.sorted { a, b in
            if a == appleHeading && b != appleHeading { return true }
            if b == appleHeading && a != appleHeading { return false }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        return keys.compactMap { key -> (String, [AIModelDescriptor])? in
            guard var list = grouped[key] else { return nil }
            list.sort {
                aiModelMenuRowTitle(for: $0).localizedCaseInsensitiveCompare(
                    aiModelMenuRowTitle(for: $1)) == .orderedAscending
            }
            return (key, list)
        }
    }

    /// Modellzeilen für `Menu` (kompakt & nicht kompakt). Kein `Picker` im `Menu` (Untermenü).
    /// SF-Symbol-Checkmarks werden von AppKit hier oft falsch als „alle aktiv“ gerendert — daher Text-Präfix.
    @ViewBuilder
    private var menuBarLLMModelRowsInMenu: some View {
        if appState.visibleAIModels.isEmpty {
            Text(text("Keine Modelle erkannt", "No models detected"))
                .disabled(true)
        } else {
            ForEach(Array(aiModelsGroupedForMenu.enumerated()), id: \.offset) { _, group in
                Section(group.section) {
                    ForEach(group.models) { model in
                        Button {
                            appState.selectedAIModelID = model.id
                        } label: {
                            Text(
                                verbatim: (appState.selectedAIModelID == model.id
                                    ? "✓ " : "\u{3000}")
                                    + aiModelMenuRowTitle(for: model))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var menuBarLLMModelMenuTrailingSelection: some View {
        Group {
            if let selected = appState.selectedAIModel {
                Text(aiModelMenuRowTitle(for: selected))
            } else if appState.visibleAIModels.isEmpty {
                Text(text("—", "—"))
            } else {
                Text(text("Auswählen…", "Choose…"))
            }
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var menuBarLLMAddModelButton: some View {
        Button {
            appState.openAISettingsWindow()
        } label: {
            Text(text("Modell hinzufügen…", "Add model…"))
        }
    }

    private var selectedVoiceModelBinding: Binding<String> {
        Binding(
            get: { appState.selectedVoiceModelID },
            set: { newValue in
                guard let descriptor = appState.voiceModels.first(where: { $0.id == newValue })
                else { return }
                guard appState.isVoiceModelInstalled(descriptor) else { return }
                appState.setSelectedVoiceModel(descriptor)
            }
        )
    }

    private var menuBarVoiceProviders: [VoiceProviderDescriptor] {
        appState.voiceProviders.filter { provider in
            selectableVoiceModels.contains(where: { $0.providerID == provider.id })
        }
    }

    private var selectableVoiceModels: [VoiceModelDescriptor] {
        appState.voiceModels.filter { appState.isVoiceModelInstalled($0) }
    }

    private var voiceModelsByProviderID: [String: [VoiceModelDescriptor]] {
        Dictionary(grouping: selectableVoiceModels, by: \.providerID)
    }

    private var menuBarPopupWidth: CGFloat {
        appState.compactMenuBarDesign ? 280 : 320
    }

    private let menuBarHistoryPreviewItemLimit = 8
    private let menuBarHistoryRowCharacterLimit = 64
    private let menuBarHistoryLabelCharacterLimit = 40

    private func historyMenuSingleLinePreview(_ raw: String, maxLength: Int) -> String {
        let single =
            raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard single.count > maxLength else { return single }
        return "\(single.prefix(maxLength))…"
    }

    private var menuBarHistoryPreviewEntries: [TranscriptHistoryEntry] {
        Array(appState.transcriptHistory.prefix(menuBarHistoryPreviewItemLimit))
    }

    private var menuBarHistoryHasMoreThanPreview: Bool {
        appState.transcriptHistory.count > menuBarHistoryPreviewItemLimit
    }

    private var insertionModeLabel: String {
        if appState.finalResultDeliveryMode == .clipboardOnly {
            return text("Zwischenablage", "Clipboard")
        }
        return appState.streamingEnabled
            ? text("Live", "Live") : text("Am Ende einfügen", "Insert on Stop")
    }

    private var statusLine: String {
        switch appState.recordingStatus {
        case "Recording":
            return text("Hört zu…", "Listening…")
        case "Error":
            return text("Aufmerksamkeit erforderlich", "Needs attention")
        case "Idle":
            if !appState.isOnboardingComplete {
                return text("Einrichtung offen", "Setup required")
            }
            if !appState.isStandardModelInstalled {
                return text("Modell fehlt", "Model missing")
            }
            switch appState.dictationCapability {
            case .fullSystemInsertion:
                return text("Bereit", "Ready")
            case .limitedTranscription:
                return text("Eingeschränkt", "Limited")
            case .unavailable:
                return text("Zugriff erforderlich", "Needs access")
            }
        default:
            return text("Aktiv", "Active")
        }
    }

    private var statusColor: Color {
        switch appState.recordingStatus {
        case "Recording":
            return .red
        case "Error":
            return .orange
        default:
            return appState.hasPermissionProblems ? .yellow : .green
        }
    }

    private var secondaryLine: String? {
        if appState.isSessionActive {
            return
                "\(appState.selectedLanguage.localizedDisplayName(interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)) • \(insertionModeLabel)"
        }
        if appState.recordingStatus == "Error" {
            return appState.statusHintText
        }
        if !appState.isOnboardingComplete {
            return text("Onboarding abschließen", "Complete onboarding")
        }
        if !appState.isStandardModelInstalled {
            return text("Standardmodell installieren", "Install standard model")
        }
        if appState.hasPermissionProblems {
            return appState.menuBarCompactPermissionHint
        }
        return nil
    }

    @ViewBuilder
    private var statusHeader: some View {
        if showsStatusHeader {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                if let secondaryLine {
                    Text(secondaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
    }

    @ViewBuilder
    private var startDictationButton: some View {
        if appState.showMenuBarShortcutHints,
            let keyEquivalent = appState.selectedHotkey.swiftUIKeyEquivalent
        {
            Button {
                appState.toggleTranscriptionFromMenuBar()
            } label: {
                PrimaryMenuActionLabel(
                    title: primaryActionTitle,
                    shortcutGlyph: nil,
                    shortcutText: appState.selectedHotkey.displayName
                )
            }
            .keyboardShortcut(
                keyEquivalent, modifiers: appState.selectedHotkey.swiftUIEventModifiers)
        } else {
            Button {
                appState.toggleTranscriptionFromMenuBar()
            } label: {
                PrimaryMenuActionLabel(
                    title: primaryActionTitle,
                    shortcutGlyph: nil,
                    shortcutText: nil
                )
            }
        }
    }

    @ViewBuilder
    private var copyLastDictationButton: some View {
        if appState.showMenuBarShortcutHints {
            Button {
                copyToClipboard(appState.latestDictationText)
            } label: {
                MenuActionLabel(
                    title: text("Letztes Diktat kopieren", "Copy last dictation"),
                    shortcutGlyph: nil,
                    shortcutText: "Command + Shift + C"
                )
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        } else {
            Button {
                copyToClipboard(appState.latestDictationText)
            } label: {
                MenuActionLabel(
                    title: text("Letztes Diktat kopieren", "Copy last dictation"),
                    shortcutGlyph: nil,
                    shortcutText: nil
                )
            }
        }
    }

    @ViewBuilder
    private var openSettingsButton: some View {
        if appState.showMenuBarShortcutHints {
            Button {
                appState.openSettingsWindow()
            } label: {
                MenuActionLabel(
                    title: text("Einstellungen…", "Settings…"),
                    shortcutGlyph: nil,
                    shortcutText: "Command + ,"
                )
            }
            .keyboardShortcut(",", modifiers: [.command])
        } else {
            Button {
                appState.openSettingsWindow()
            } label: {
                MenuActionLabel(
                    title: text("Einstellungen…", "Settings…"),
                    shortcutGlyph: nil,
                    shortcutText: nil
                )
            }
        }
    }

    @ViewBuilder
    private var menuBarPermissionSection: some View {
        if appState.hasPermissionProblems {
            if !appState.compactMenuBarDesign {
                Text(text("Berechtigungen", "Permissions"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if appState.microphonePermissionStatus != .granted {
                if appState.microphonePermissionStaleAfterRebuild {
                    Button(text("Mikrofon neu verknüpfen", "Rebind microphone")) {
                        appState.rebindMicrophonePermissions()
                    }
                } else {
                    Button(text("Mikrofon freigeben", "Grant microphone access")) {
                        appState.requestMicrophoneAccessFromSettings()
                    }
                }
            }
            if appState.accessibilityPermissionStatus != .granted {
                if appState.accessibilityPermissionStaleAfterRebuild {
                    Button(text("Bedienungshilfen neu verknüpfen", "Rebind accessibility")) {
                        appState.rebindAccessibilityPermissions()
                    }
                } else {
                    Button(text("Bedienungshilfen freigeben", "Grant accessibility access")) {
                        appState.requestAccessibilityAccessFromSettings()
                    }
                }
            }
            Divider()
        }
    }

    /// LLM-Auswahl inkl. „Modell hinzufügen“ — Label unterscheidet kompakt (nur Titel) vs. Zeile mit aktueller Auswahl.
    @ViewBuilder
    private var menuBarLLMModelMenu: some View {
        Menu {
            menuBarLLMModelRowsInMenu

            Divider()

            menuBarLLMAddModelButton
        } label: {
            if appState.compactMenuBarDesign {
                MenuActionLabel(
                    title: text("LLM Modell", "LLM model"),
                    shortcutGlyph: nil,
                    shortcutText: nil
                )
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(text("LLM Modell", "LLM model"))
                    Spacer(minLength: 8)
                    menuBarLLMModelMenuTrailingSelection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Gemeinsame Untermenüs für kompakt und nicht kompakt (keine abhängigen Stil-/Anrede-/Modus-Picker).
    @ViewBuilder
    private var menuBarSharedAIFeatureMenus: some View {
        Menu {
            Toggle(
                text("Inhaltsstreaming", "Content streaming"),
                isOn: $appState.aiProcessingApplyDuringLiveInsertion
            )
            .disabled(!appState.streamingEnabled || appState.visibleAIModels.isEmpty)

            Toggle(
                text("Endergebnis einfügen", "Insert final result"),
                isOn: $appState.aiProcessingApplyToFinalResult
            )
            .disabled(appState.visibleAIModels.isEmpty)
        } label: {
            MenuActionLabel(
                title: text("AI anwenden bei", "Apply AI for"),
                shortcutGlyph: nil,
                shortcutText: nil
            )
        }

        Menu {
            Toggle(text("Stil / Ton", "Style / Tone"), isOn: $appState.aiTaskToneEnabled)
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)
            Toggle(text("Anrede", "Salutation"), isOn: $appState.aiTaskSalutationEnabled)
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)
            Toggle(text("Format / Modus", "Format / Mode"), isOn: $appState.aiTaskFormatEnabled)
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)
            Toggle(text("Bereinigen", "Clean up"), isOn: $appState.aiTaskCleanupEnabled)
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)
        } label: {
            MenuActionLabel(
                title: text("AI-Aufgaben", "AI tasks"),
                shortcutGlyph: nil,
                shortcutText: nil
            )
        }
    }

    /// Nicht kompakt: Verlauf wie LLM-Menü — Zeilen tippen kopiert; unten ggf. Sprung ins Einstellungsfenster.
    @ViewBuilder
    private var menuBarNonCompactHistoryMenu: some View {
        Menu {
            ForEach(menuBarHistoryPreviewEntries) { entry in
                Button {
                    copyToClipboard(entry.text)
                } label: {
                    Text(
                        historyMenuSingleLinePreview(
                            entry.text,
                            maxLength: menuBarHistoryRowCharacterLimit
                        )
                    )
                }
                .accessibilityLabel(
                    text(
                        "Vollständigen Verlaufstext in die Zwischenablage kopieren",
                        "Copy full history item to clipboard"
                    )
                )
            }
            if menuBarHistoryHasMoreThanPreview {
                Divider()
                Button {
                    appState.openHistorySettingsWindow()
                } label: {
                    Text(
                        text(
                            "Gesamten Verlauf anzeigen…",
                            "Show full history…")
                    )
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(text("Verlauf", "History"))
                Spacer(minLength: 8)
                if let newest = appState.transcriptHistory.first {
                    Text(
                        historyMenuSingleLinePreview(
                            newest.text,
                            maxLength: menuBarHistoryLabelCharacterLimit
                        )
                    )
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Nur nicht kompakt: Stil-/Anrede-/Modus-Picker (abhängig von AI-Aufgaben).
    @ViewBuilder
    private var menuBarNonCompactAIDetailPickers: some View {
        if appState.aiShowsWritingStyleControls {
            Picker(text("Stil", "Style"), selection: $appState.aiWritingStyle) {
                ForEach(appState.availableAIWritingStyles) { style in
                    Text(
                        style.localizedDisplayName(
                            interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                    )
                    .tag(style)
                }
            }
            .disabled(appState.selectedAIModel?.availability.isAvailable != true)
        }

        if appState.aiShowsSalutationControls {
            Picker(text("Anrede", "Salutation"), selection: $appState.aiSalutation) {
                ForEach(AISalutation.allCases) { salutation in
                    Text(
                        salutation.localizedDisplayName(
                            interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                    )
                    .tag(salutation)
                }
            }
            .disabled(appState.selectedAIModel?.availability.isAvailable != true)
        }

        if appState.aiShowsModeControls {
            Picker(text("Formatierung", "Formatting"), selection: $appState.aiFormattingMode) {
                ForEach(AIFormattingMode.allCases) { mode in
                    Text(
                        mode.localizedDisplayName(
                            interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                    )
                    .tag(mode)
                }
            }
            .disabled(appState.selectedAIModel?.availability.isAvailable != true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            startDictationButton

            Divider()

            menuBarPermissionSection

            statusHeader

            if showsStatusHeader {
                Divider()
            }

            Toggle(text("Live-Text einfügen", "Insert live text"), isOn: $appState.streamingEnabled)
                .disabled(appState.finalResultDeliveryMode == .clipboardOnly)

            Picker(text("Sprache", "Language"), selection: $appState.selectedLanguage) {
                ForEach(visibleMenuBarLanguages) { language in
                    Text(
                        language.localizedDisplayName(
                            interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                    )
                    .tag(language)
                }
            }

            Picker(text("Übersetzung", "Translation"), selection: $appState.translationOutputMode) {
                ForEach(TranslationOutputMode.allCases) { mode in
                    Text(
                        mode.localizedDisplayName(
                            interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                    )
                    .tag(mode)
                }
            }

            if !appState.compactMenuBarDesign {
                if menuBarVoiceProviders.isEmpty {
                    Text(text("Keine installierten Modelle", "No installed models"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        text("Sprachmodell", "Voice model"), selection: selectedVoiceModelBinding
                    ) {
                        ForEach(menuBarVoiceProviders) { provider in
                            if let models = voiceModelsByProviderID[provider.id], !models.isEmpty {
                                Section(provider.displayName) {
                                    ForEach(models) { model in
                                        Text(model.displayName).tag(model.id)
                                    }
                                }
                            }
                        }
                    }
                }

                Picker(text("Qualität", "Quality"), selection: $appState.performanceProfile) {
                    ForEach(DictationPerformance.allCases) { profile in
                        Text(
                            profile.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(profile)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle(
                    text("AI-Verarbeitung", "AI processing"), isOn: $appState.aiProcessingEnabled
                )
                .disabled(!hasQuickSettingsAIModels)

                if appState.aiProcessingEnabled {
                    menuBarLLMModelMenu
                    menuBarSharedAIFeatureMenus
                    if !appState.compactMenuBarDesign {
                        menuBarNonCompactAIDetailPickers
                    }
                }
            }

            if menuBarShowsDictationHistorySection {
                Divider()
                if !appState.latestDictationText.isEmpty {
                    copyLastDictationButton
                }
                if appState.compactMenuBarDesign {
                    Button(text("Verlauf…", "History…")) {
                        appState.openHistorySettingsWindow()
                    }
                } else if !appState.transcriptHistory.isEmpty {
                    menuBarNonCompactHistoryMenu
                }
            }

            Divider()

            openSettingsButton

            if showsUpdateMenuItem {
                Button(text("Nach Updates suchen", "Check for updates")) {
                    appState.checkForUpdates()
                }
                .buttonStyle(.borderless)
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                MenuActionLabel(
                    title: text("Beenden", "Quit"),
                    shortcutGlyph: appState.showMenuBarShortcutHints ? "⌘Q" : nil,
                    shortcutText: appState.showMenuBarShortcutHints ? "Command + Q" : nil
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(width: menuBarPopupWidth, alignment: .leading)
        .clipped()
        .controlSize(.small)
        .onAppear {
            appState.refreshPermissionStatesWithStabilization()
        }
    }

    private func copyToClipboard(_ string: String) {
        guard !string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

private struct MenuActionLabel: View {
    let title: String
    let shortcutGlyph: String?
    let shortcutText: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 12)
            if let shortcutGlyph, !shortcutGlyph.isEmpty {
                Text(shortcutGlyph)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shortcutText.map { "\(title), \($0)" } ?? title)
    }
}

private struct PrimaryMenuActionLabel: View {
    let title: String
    let shortcutGlyph: String?
    let shortcutText: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.body.weight(.semibold))
            Spacer(minLength: 12)
            if let shortcutGlyph, !shortcutGlyph.isEmpty {
                Text(shortcutGlyph)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .menuBarPrimaryActionSurface(cornerRadius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shortcutText.map { "\(title), \($0)" } ?? title)
    }
}
