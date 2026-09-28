import ASRCore
import SwiftUI

extension SettingsView {
    @ViewBuilder
    var generalAppearanceContent: some View {
        if matches(["language", "sprache", "dock", "launch on login", "updates"]) {
            LabeledContent {
                Picker(text("App-Sprache", "App Language"), selection: $uiLanguageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.pickerDisplayName(uiContentLanguage: effectiveLanguage)).tag(
                            language.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 170)
            } label: {
                SettingsFieldLabel(title: text("App-Sprache", "App language"))
            }

            Toggle(text("Im Dock anzeigen", "Show in Dock"), isOn: $appState.showInDock)

            Toggle(isOn: $appState.launchOnLoginEnabled) {
                SettingsFieldLabel(
                    title: text("Beim Anmelden starten", "Launch on login"),
                    helpText: text(
                        "Startet Cortexa automatisch nach der macOS-Anmeldung.",
                        "Starts Cortexa automatically after you sign in to macOS."
                    )
                )
            }

            if appState.updaterConfigured {
                Toggle(isOn: $appState.automaticallyCheckForUpdates) {
                    SettingsFieldLabel(
                        title: text("Updates automatisch prüfen", "Automatically check for updates"),
                        helpText: text(
                            "Prüft im Hintergrund regelmäßig über Sparkle, ob eine neuere Version verfügbar ist.",
                            "Checks in the background via Sparkle to see whether a newer version is available."
                        )
                    )
                }
            }
            let runtime = VoiceModelInstaller.nemoRuntimeStatusSnapshot()
            LabeledContent("NeMo-Speech Runtime") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(runtime.isAvailable
                        ? text(
                            "\(runtime.isManaged ? "Cortexa-verwaltet" : "Extern erkannt") · Version \(runtime.version ?? "unbekannt")",
                            "\(runtime.isManaged ? "Managed by Cortexa" : "External runtime detected") · version \(runtime.version ?? "unknown")"
                        )
                        : text(
                            "Keine kompatible Runtime · wird bei der Parakeet-Installation eingerichtet",
                            "No compatible runtime · Cortexa installs it with Parakeet"
                        ))
                        .font(.footnote)
                        .foregroundStyle(runtime.isAvailable ? Color.secondary : Color.orange)
                    if let diagnostic = runtime.diagnostic {
                        Text(diagnostic).font(.caption).foregroundStyle(.secondary)
                    }
                    let hasRuntimeDependentModel = appState.allVoiceModels.contains {
                        $0.runtimeID == "nemo-speech" && appState.isVoiceModelInstalled($0)
                    }
                    if runtime.isManaged && !hasRuntimeDependentModel {
                        Button(text("Nicht mehr benötigte Runtime bereinigen", "Remove unused runtime")) {
                            appState.retryUnusedNemoRuntimeCleanup()
                        }
                        .font(.footnote)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var generalMenuBarContent: some View {
        if matches(["menüleiste", "menu bar", "shortcut hints", "compact", "kompakt"]) {
            Toggle(isOn: $appState.compactMenuBarDesign) {
                SettingsFieldLabel(
                    title: text("Kompaktes Menüleisten-Design", "Compact menu bar design"),
                    helpText: text(
                        "Macht das Menüleisten-Popup schmaler und ruhiger, lässt aber Verlauf, Kopieren und Trennlinien sichtbar.",
                        "Makes the menu bar popup narrower and calmer while keeping history, copy actions, and separators visible."
                    )
                )
            }

            Toggle(isOn: $appState.showMenuBarShortcutHints) {
                SettingsFieldLabel(
                    title: text(
                        "Kurzbefehl-Hinweise im Menü anzeigen", "Show shortcut hints in menu"),
                    helpText: text(
                        "Zeigt Tastenkombinationen direkt neben passenden Einträgen im Menüleisten-Menü an.",
                        "Shows keyboard shortcuts directly next to matching menu bar items."
                    )
                )
            }
        }
    }

    var advancedOverviewContent: some View {
        Text(
            text(
                "Hier liegen Laufzeitoptionen, Speicherort, Updates und technische Diagnose. Nur ändern, wenn du weißt, warum du es brauchst.",
                "Model runtime, storage location, updates, and technical diagnostics live here. Change these only when you know why you need them."
            )
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    var advancedStorageContent: some View {
        if matches([
            "storage", "folder", "app support", "speicherort", "datenordner", "app folder", "logs",
            "protokolle",
        ]) {
            LabeledContent {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appState.appSupportDirectoryPathText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button(text("Ordner im Finder öffnen", "Open folder in Finder")) {
                        appState.revealAppDataFolder()
                    }
                    .liquidGlassSecondaryButtonStyle()
                }
            } label: {
                SettingsFieldLabel(
                    title: text("App-Datenordner", "App data folder"),
                    helpText: text(
                        "Hier liegen Verlauf, Snippets, Logs und weitere lokale App-Daten.",
                        "This folder stores history, snippets, logs, and other local app data."
                    )
                )
            }
        }
    }

    @ViewBuilder
    var voiceModelRuntimeContent: some View {
        if matches([
            "voice", "sprachmodell", "model runtime", "runtime", "duration", "dauer", "warm",
            "speicher halten", "modelllaufzeit",
        ]) {
            LabeledContent {
                Picker(
                    text("Sprachmodell im Speicher halten", "Keep voice model in memory"),
                    selection: $appState.voiceModelActiveDuration
                ) {
                    ForEach(VoiceModelActiveDuration.allCases) { duration in
                        Text(
                            duration.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(duration)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 220)
            } label: {
                SettingsFieldLabel(
                    title: text("Sprachmodell im Speicher halten", "Keep voice model in memory"),
                    helpText: text(
                        "Längere Laufzeiten machen den nächsten Start schneller, kürzere sparen Speicher.",
                        "Longer durations make the next start faster, shorter ones save memory."
                    )
                )
            }
        }
    }

    @ViewBuilder
    var updatesContent: some View {
        if matches(["update", "updates", "aktualisierung"]) {
            VStack(alignment: .leading, spacing: 12) {
                if appState.updaterConfigured {
                    HStack(alignment: .center, spacing: 10) {
                        Button(text("Nach Updates suchen", "Check for updates")) {
                            appState.checkForUpdates()
                        }
                        .liquidGlassSecondaryButtonStyle()

                        if !appState.updaterStatusText.isEmpty {
                            Text(appState.updaterStatusText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                } else {
                    Text(
                        text(
                            "Automatische Updates sind für diesen Build nicht konfiguriert. Releases werden über GitHub bereitgestellt; Sparkle wird erst aktiv, wenn Feed-URL und Public-Key im Build gesetzt sind.",
                            "Automatic updates are not configured for this build. Releases are distributed through GitHub; Sparkle becomes active only when the feed URL and public key are set in the build."
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if !appState.updaterFeedURLText.isEmpty {
                    Text(appState.updaterFeedURLText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    var aboutAppInfoRows: some View {
        LabeledContent(text("App", "App")) {
            Text("Cortexa")
        }
        LabeledContent(text("Version", "Version")) {
            Text("\(appMarketingVersion) (\(appBuildNumber))")
                .monospacedDigit()
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    var aboutDeveloperRows: some View {
        if matches([
            "about", "über", "ueber", "leon", "stadler", "website", "webseite", "apache",
            "open source", "open-source", "lizenz", "intermedia", "design", "fotografie", "vorarlberg",
        ]) {
            Image("CortexaLogoHorizontal")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260, maxHeight: 72, alignment: .leading)
                .foregroundStyle(.primary)
                .accessibilityLabel(text("Cortexa-Logo", "Cortexa logo"))

            LabeledContent(text("Entwickler", "Developer")) {
                Text("Leon Stadler")
            }
            Text(
                text(
                    "Ich entwickle digitale Produkte mit Fokus auf ruhige, native Oberflächen, gute Workflows und lokale Kontrolle.",
                    "I build digital products focused on calm native interfaces, practical workflows, and local control."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                text(
                    "Cortexa ist eine lokale, datensparsame Diktierlösung für den Mac.",
                    "Cortexa is a local, privacy-conscious dictation tool for the Mac."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Link(destination: personalWebsiteURL) {
                Text(text("Website besuchen", "Visit website"))
            }
            .liquidGlassPrimaryButtonStyle()
        }
    }

    @ViewBuilder
    var aboutChangelogContent: some View {
        if matches([
            "changelog", "neuigkeiten", "release", "release notes", "änderungen", "aenderungen",
            "features", "fixes",
        ]) {
            ChangelogSectionView(
                entries: AppChangelogCatalog.latestEntries, language: effectiveLanguage)
        }
    }

    @ViewBuilder
    var aboutSupportContent: some View {
        if matches(["support", "spenden", "donate", "website", "webseite"]) {
            Text(
                text(
                    "Cortexa ist unter Apache 2.0 quelloffen lizenziert. Issues, Releases und technische Details liegen im Repository.",
                    "Cortexa is open source under Apache 2.0. Issues, releases, and technical details live in the repository."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Link(destination: projectRepositoryURL) {
                    Label(text("Repository öffnen", "Open repository"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .liquidGlassPrimaryButtonStyle()

                Link(destination: personalWebsiteURL) {
                    Label(text("Website besuchen", "Visit website"), systemImage: "safari")
                }
                .liquidGlassSecondaryButtonStyle()
            }
        }
    }

    @ViewBuilder
    var generalPermissionsContent: some View {
        if matches([
            "mikrofon", "accessibility", "bedienungshilfen", "permissions", "berechtigungen",
        ]) && permissionsNeedAttention {
            VStack(alignment: .leading, spacing: 10) {
                if appState.microphonePermissionStatus != .granted {
                    PermissionWarningTile(
                        title: text("Mikrofon", "Microphone"),
                        message: text(
                            "Für die Aufnahme fehlt noch die Mikrofonfreigabe.",
                            "Microphone access is required to record dictation."
                        ),
                        status: appState.microphonePermissionStatus,
                        actionTitle: appState.microphonePermissionStatus == .notDetermined
                            ? text("Freigabe anfragen", "Request access")
                            : text("Systemeinstellungen öffnen", "Open System Settings"),
                        actionHint: text(
                            "Mikrofonfreigabe in den Systemeinstellungen verwalten.",
                            "Manage microphone access in System Settings."
                        ),
                        action: {
                            if appState.microphonePermissionStatus == .notDetermined {
                                appState.requestMicrophoneAccessFromSettings()
                            } else {
                                appState.openMicrophoneSettings()
                            }
                        }
                    )
                }

                if appState.accessibilityPermissionStatus != .granted {
                    PermissionWarningTile(
                        title: text("Bedienungshilfen", "Accessibility"),
                        message: text(
                            "Für das Einfügen in das aktive Textfeld fehlt noch die Freigabe.",
                            "Accessibility access is required to insert text into the active field."
                        ),
                        status: appState.accessibilityPermissionStatus,
                        actionTitle: text("Freigabe anfragen", "Request access"),
                        actionHint: text(
                            "Bedienungshilfen-Freigabe in den Systemeinstellungen verwalten.",
                            "Manage Accessibility access in System Settings."
                        ),
                        action: { appState.requestAccessibilityAccessFromSettings() }
                    )
                }
            }
        }
    }

    @ViewBuilder
    var advancedPermissionsContent: some View {
        if matches([
            "mikrofon", "accessibility", "bedienungshilfen", "permissions", "berechtigungen",
        ]) {
            permissionsRowsContent
        }
    }

    private var permissionsNeedAttention: Bool {
        appState.microphonePermissionStatus != .granted
            || appState.accessibilityPermissionStatus != .granted
    }

    private var permissionsRowsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                PermissionStatusRow(
                    title: text("Mikrofon", "Microphone"),
                    status: appState.microphonePermissionStatus,
                    detail: text("Audioaufnahme.", "Audio capture."),
                    statusLabel: permissionStatusLabel(
                        appState.microphonePermissionStatus,
                        deniedLabel: text("Nicht freigegeben", "Not allowed")
                    ),
                    actionTitle: appState.microphonePermissionStatus == .notDetermined
                        ? text("Freigabe anfragen", "Request access")
                        : text("Öffnen", "Open"),
                    actionHint: appState.microphonePermissionStatus == .notDetermined
                        ? text(
                            "Systemdialog zur Mikrofonfreigabe", "System prompt for microphone access")
                        : text("Mikrofon-Einstellungen öffnen", "Open microphone settings"),
                    action: {
                        if appState.microphonePermissionStatus == .notDetermined {
                            appState.requestMicrophoneAccessFromSettings()
                        } else {
                            appState.openMicrophoneSettings()
                        }
                    }
                )

                Divider()

                PermissionStatusRow(
                    title: text("Bedienungshilfen", "Accessibility"),
                    status: appState.accessibilityPermissionStatus,
                    detail: text("Einfügen ins aktive Textfeld.", "Insert into the active field."),
                    statusLabel: permissionStatusLabel(
                        appState.accessibilityPermissionStatus,
                        deniedLabel: text("Nicht freigegeben", "Not allowed")
                    ),
                    actionTitle: appState.accessibilityPermissionStatus != .granted
                        ? text("Freigabe anfragen", "Request access")
                        : text("Öffnen", "Open"),
                    actionHint: appState.accessibilityPermissionStatus != .granted
                        ? text(
                            "Zeigt den macOS-Hinweis. Von dort kannst du die Systemeinstellungen öffnen.",
                            "Shows the macOS prompt. From there, you can open System Settings.")
                        : text("Bedienungshilfen öffnen", "Open accessibility settings"),
                    action: {
                        if appState.accessibilityPermissionStatus != .granted {
                            appState.requestAccessibilityAccessFromSettings()
                        } else {
                            appState.openAccessibilitySettings()
                        }
                    }
                )
            }
            .padding(.vertical, 6)

            Text(appState.dictationCapability.localizedSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    func permissionStatusLabel(_ status: PermissionStatus, deniedLabel: String) -> String {
        switch status {
        case .granted:
            return text("Freigegeben", "Allowed")
        case .denied, .notDetermined:
            return deniedLabel
        case .restricted:
            return text("Eingeschränkt", "Restricted")
        }
    }

    @ViewBuilder
    var soundInputContent: some View {
        if soundHasMatches {
            Toggle(isOn: $appState.automaticMicrophoneGainBoost) {
                SettingsFieldLabel(
                    title: text("Leise Eingänge verstärken", "Boost quiet input"),
                    helpText: text(
                        "Hebt ein schwaches Eingangssignal an, bevor die Erkennung startet. Das ändert nicht die systemweite Mikrofonlautstärke.",
                        "Boosts a weak input signal before recognition begins. This does not change the system-wide microphone volume."
                    )
                )
            }
            Toggle(isOn: $appState.silenceRemovalEnabled) {
                SettingsFieldLabel(
                    title: text("Stille entfernen", "Silence removal"),
                    helpText: text(
                        "Filtert ruhige Abschnitte und schwache Störgeräusche vor der Erkennung. Das hilft besonders bei Live-Einfügen gegen Atem-, Raum- oder Tastaturreste.",
                        "Filters quiet passages and weak background noise before recognition. This is especially useful during live insertion against breathing, room, or keyboard residue."
                    )
                )
            }

            LabeledContent {
                VStack(alignment: .trailing, spacing: 6) {
                    Slider(value: $appState.noiseSuppressionLevel, in: 0...1, step: 0.05)
                        .frame(maxWidth: 300)
                    Text(
                        text("Filterstärke", "Filter strength")
                            + ": \(Int((appState.noiseSuppressionLevel * 100).rounded()))%"
                    )
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                SettingsFieldLabel(
                    title: text("Störgeräusche filtern", "Filter background noise"),
                    helpText: text(
                        "Steuert, wie aggressiv leise Nebengeräusche und kurze Nicht-Sprachsignale unterdrückt werden. Höher hilft bei Husten, Atemgeräuschen oder Raumrauschen, kann aber sehr leise Sprache früher abschneiden.",
                        "Controls how aggressively quiet background noise and short non-speech signals are suppressed. Higher values help with coughing, breathing, or room noise, but may cut very quiet speech earlier."
                    )
                )
            }
            .disabled(!appState.silenceRemovalEnabled)

            Toggle(isOn: $appState.dynamicNormalizationEnabled) {
                SettingsFieldLabel(
                    title: text("Dynamische Normalisierung", "Dynamic normalization"),
                    helpText: text(
                        "Gleicht Lautstärkeunterschiede innerhalb des laufenden Signals aus. Anders als die Eingangsverstärkung reagiert diese Option auf wechselnde Pegel während der Aufnahme.",
                        "Balances loudness differences inside the live signal. Unlike quiet-input boosting, this reacts to changing levels while recording."
                    )
                )
            }
        }
    }

    @ViewBuilder
    var soundFeedbackContent: some View {
        if soundHasMatches {
            Toggle(isOn: $appState.soundEffectsEnabled) {
                SettingsFieldLabel(
                    title: text("Soundeffekte aktivieren", "Enable sound effects"),
                    helpText: text(
                        "Spielt kurze Statussignale beim Starten, Stoppen oder bei wichtigen Zustandswechseln ab.",
                        "Plays short status cues when starting, stopping, or when important states change."
                    )
                )
            }

            LabeledContent {
                VStack(alignment: .trailing, spacing: 6) {
                    Slider(value: $appState.soundEffectsVolume, in: 0...100, step: 5)
                        .frame(maxWidth: 300)
                    Text(
                        text("Lautstärke", "Volume")
                            + ": \(Int(appState.soundEffectsVolume.rounded()))%"
                    )
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                SettingsFieldLabel(
                    title: text("Lautstärke", "Volume"),
                    helpText: text(
                        "Regelt nur die internen App-Sounds, nicht die Systemlautstärke.",
                        "Controls only the app's internal sounds, not the system volume."
                    )
                )
            }
            .disabled(!appState.soundEffectsEnabled)
        }
    }

    @ViewBuilder
    var speechProviderContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(
                    text("Voice-Anbieter", "Voice provider"),
                    selection: $appState.selectedVoiceProviderID
                ) {
                    ForEach(appState.voiceProviders) { provider in
                        Text(
                            provider.isAvailable
                                ? provider.displayName
                                : "\(provider.displayName) · \(text("Runtime fehlt", "runtime missing"))"
                        )
                        .tag(provider.id)
                        .disabled(!provider.isAvailable)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 240)
            } label: {
                SettingsFieldLabel(
                    title: text("Voice-Anbieter", "Voice provider"),
                    helpText: text(
                        "V1 bleibt komplett lokal. Zusätzliche Anbieter erscheinen nur, wenn ihr lokales Backend wirklich vorhanden ist.",
                        "V1 stays fully local. Additional providers only appear when their local backend is actually available."
                    )
                )
            }
        }
    }

    @ViewBuilder
    var speechOverviewContent: some View {
        if speechHasMatches {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    text(
                        "Modell, Sprache und Übersetzung sind getrennt. Das Modell bestimmt Größe, Tempo und Fähigkeiten. Die Sprache begrenzt nur die sinnvollen Eingaben.",
                        "Model, language, and translation are separate. The model defines size, speed, and capabilities. Language only limits the sensible input choices."
                    )
                )
                .font(.subheadline)

                Text(
                    text(
                        "Qualität steuert Beam-Search, Chunking und Threads. Sie ändert nicht mehr das eigentliche Modell.",
                        "Quality controls beam search, chunking, and threads. It no longer changes the actual model."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
