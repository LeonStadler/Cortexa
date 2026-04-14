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
                        "Startet WisprLocal automatisch nach der macOS-Anmeldung.",
                        "Starts WisprLocal automatically after you sign in to macOS."
                    )
                )
            }

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
                HStack(alignment: .center, spacing: 10) {
                    Button(text("Nach Updates suchen", "Check for updates")) {
                        appState.checkForUpdates()
                    }
                    .liquidGlassSecondaryButtonStyle()
                    .disabled(!appState.updaterConfigured)

                    if !appState.updaterStatusText.isEmpty {
                        Text(appState.updaterStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
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
            Text("WisprLocal")
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
            "about", "über", "ueber", "leon", "stadler", "website", "webseite", "proprietär",
            "proprietary", "lizenz", "intermedia", "design", "fotografie", "vorarlberg",
        ]) {
            LabeledContent(text("Entwickler", "Developer")) {
                Text("Leon Stadler")
            }
            Text(
                text(
                    "Ich bin in München aufgewachsen, lebe heute am Bodensee und arbeite an digitalen Produkten, die Design, Technik und Alltag sinnvoll verbinden. Schwerpunkte sind Webdesign, UX/UI, Prototyping und kreative technische Systeme — mit einem starken Blick auf ruhige, native Oberflächen.",
                    "I grew up in Munich and now live near Lake Constance, building digital products that connect design, technology, and everyday work. My focus is web design, UX/UI, prototyping, and creative technical systems — with a strong preference for calm, native-feeling interfaces."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                text(
                    "WisprLocal ist daraus entstanden: eine lokale, datensparsame Diktierlösung für den Mac, die sich nicht aufdrängt, sondern zuverlässig im Hintergrund mitarbeitet.",
                    "WisprLocal grew out of that mindset: a local, privacy-conscious dictation tool for the Mac that stays out of the way while remaining dependable."
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
                    "WisprLocal ist proprietäre Software und wird nicht als Open Source veröffentlicht. Support, Lizenzierung und Hintergrund zum Projekt findest du auf der Website.",
                    "WisprLocal is proprietary software and is not distributed as open source. Visit the website for support, licensing, and project information."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Link(destination: personalWebsiteURL) {
                Label(text("Projekt unterstützen", "Support the project"), systemImage: "heart")
            }
            .liquidGlassPrimaryButtonStyle()
        }
    }

    @ViewBuilder
    var generalPermissionsContent: some View {
        if matches([
            "mikrofon", "accessibility", "bedienungshilfen", "permissions", "berechtigungen",
        ]) {
            Text(
                text(
                    "Freigaben kannst du hier prüfen. „Freigabe anfragen“ öffnet den Systemdialog; „Öffnen“ führt zu den Datenschutz-Einstellungen. Direkt nach einem App-Neustart kann der Status einmal kurz hinterherhängen – dann erneut öffnen oder kurz warten. Falls Bedienungshilfen nach einem Rebuild weiter blockieren, in den Systemeinstellungen WisprLocalMac einmal entfernen und neu hinzufügen.",
                    "You can verify access here. “Request access” shows the system prompt; “Open” goes to Privacy settings. Right after launching the app, the status row can briefly lag—open again or wait a moment."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            PermissionStatusRow(
                title: text("Mikrofon", "Microphone"),
                status: appState.microphonePermissionStatus,
                detail: text("Erforderlich für die Audioaufnahme.", "Required for audio capture."),
                actionTitle: appState.microphonePermissionStatus == .notDetermined
                    ? text("Freigabe anfragen", "Request access")
                    : text("Öffnen", "Open"),
                actionHint: appState.microphonePermissionStatus == .notDetermined
                    ? text("Systemdialog zur Mikrofonfreigabe", "System prompt for microphone access")
                    : text("Mikrofon-Einstellungen öffnen", "Open microphone settings"),
                action: {
                    if appState.microphonePermissionStatus == .notDetermined {
                        appState.requestMicrophoneAccessFromSettings()
                    } else {
                        appState.openMicrophoneSettings()
                    }
                }
            )

            PermissionStatusRow(
                title: text("Bedienungshilfen", "Accessibility"),
                status: appState.accessibilityPermissionStatus,
                detail: text(
                    "Erforderlich zum Einfügen in das aktive Textfeld.",
                    "Required to insert into the active text field."),
                actionTitle: appState.accessibilityPermissionStatus != .granted
                    ? text("Freigabe anfragen", "Request access")
                    : text("Öffnen", "Open"),
                actionHint: appState.accessibilityPermissionStatus != .granted
                    ? text(
                        "Systemdialog zu Bedienungshilfen",
                        "System prompt for Accessibility")
                    : text("Bedienungshilfen öffnen", "Open accessibility settings"),
                action: {
                    if appState.accessibilityPermissionStatus != .granted {
                        appState.requestAccessibilityAccessFromSettings()
                    } else {
                        appState.openAccessibilitySettings()
                    }
                }
            )

            Text(appState.dictationCapability.localizedSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                        Text(provider.displayName).tag(provider.id)
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
