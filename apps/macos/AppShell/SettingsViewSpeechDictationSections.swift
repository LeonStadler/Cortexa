import ASRCore
import SwiftUI

extension SettingsView {
    @ViewBuilder
    var speechModelSelectionContent: some View {
        if speechHasMatches {
            LabeledContent {
                if appState.visibleSelectableVoiceModels.isEmpty {
                    Text(text("Keine installierten Modelle", "No installed models"))
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        text("Voice-Modell", "Voice model"),
                        selection: $appState.selectedVoiceModelID
                    ) {
                        ForEach(appState.visibleSelectableVoiceModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .settingsFormMenuPickerSlot(minWidth: 240)
                }
            } label: {
                SettingsFieldLabel(
                    title: text("Voice-Modell", "Voice model"),
                    helpText: text(
                        "Das Modell bestimmt die tatsächliche Transkriptions-Engine.",
                        "The model defines the actual transcription engine."
                    )
                )
            }
        }
    }

    @ViewBuilder
    var speechLanguageContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(
                    text("Eingabesprache", "Input language"), selection: $appState.selectedLanguage
                ) {
                    ForEach(appState.selectedVoiceModelLanguageOptions) { language in
                        Text(
                            language.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 180)
            } label: {
                SettingsFieldLabel(
                    title: text("Eingabesprache", "Input language"),
                    helpText: text(
                        "Bei multilingualen Modellen kann die Sprache frei gewählt werden. Bei rein englischen Modellen reduziert sich die Auswahl automatisch.",
                        "For multilingual models you can choose freely. For English-only models the picker is reduced automatically."
                    )
                )
            }

            if let selectedModel = appState.selectedVoiceModel {
                Text(
                    selectedModel.languageCode == nil
                        ? text(
                            "Multilinguales Modell: alle Sprachen verfügbar.",
                            "Multilingual model: all languages available.")
                        : text(
                            "Sprache ist an das Modell gebunden.", "Language is bound to the model."
                        )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                if let hint = appState.selectedVoiceModelLanguageHintText {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var speechQualityContent: some View {
        if speechHasMatches {
            LabeledContent {
                Picker(
                    text("Qualitätsprofil", "Quality profile"),
                    selection: $appState.performanceProfile
                ) {
                    ForEach(DictationPerformance.allCases) { mode in
                        Text(
                            mode.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        )
                        .tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 180)
            } label: {
                SettingsFieldLabel(
                    title: text("Qualitätsprofil", "Quality profile"),
                    helpText: text(
                        "Steuert Laufzeitparameter wie Beam-Search, Chunking und Threads.",
                        "Controls runtime parameters like beam search, chunking, and threads."
                    )
                )
            }

            Text(
                text(
                    "Auto passt das Preset an Gerät und Laufzeit an. Schnell priorisiert Reaktionszeit, Ausgeglichen balanciert Stabilität und Tempo, Präzise investiert mehr in die finale Erkennung.",
                    "Auto adapts the preset to the device and runtime. Fast prioritizes responsiveness, Balanced trades speed for stability, and Accurate spends more on the final recognition pass."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let selectedModel = appState.selectedVoiceModel {
                LabeledContent(text("Modell-Details", "Model details")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            "\(text("Bereich", "Scope")): \(selectedModel.languageCode?.uppercased() ?? "ALL")"
                        )
                        Text(
                            "\(text("Übersetzung", "Translation")): \(selectedModel.supportsTranslationToEnglish ? text("Ja", "Yes") : text("Nein", "No"))"
                        )
                        Text(
                            "\(text("Geschwindigkeit", "Speed")) \(selectedModel.speedScore)/10  \(text("Genauigkeit", "Accuracy")) \(selectedModel.accuracyScore)/10  \(selectedModel.sizeLabel)"
                        )
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    var translationContent: some View {
        if speechHasMatches, appState.speechTranslationAvailable {
            LabeledContent {
                Picker(
                    text("Übersetzen nach", "Translate to"),
                    selection: $appState.translationOutputMode
                ) {
                    ForEach(TranslationOutputMode.allCases) { mode in
                        Text(
                            mode.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        )
                        .tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 170)
                .disabled(!appState.speechTranslationAvailable)
            } label: {
                SettingsFieldLabel(
                    title: text("Übersetzen nach", "Translate to"),
                    helpText: text(
                        "Die Option \"Keine Übersetzung\" gibt die gesprochene Sprache zurück. Die Option \"Nach Englisch\" aktiviert ausschließlich die lokale Whisper-Übersetzung. Sprachspezifische English-Modelle unterstützen das nicht.",
                        "The Option \"No translation\" returns the spoken language. The Option \"To English\" enables only local Whisper translation. Language-specific English models do not support this."
                    )
                )
            }
        } else if speechHasMatches {
            Text(
                text(
                    "Dieses Modell unterstützt keine Übersetzung.",
                    "This model does not support translation."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var installedSpeechModelsContent: some View {
        if speechHasMatches {
            ForEach(appState.visibleVoiceModels) { model in
                LabeledContent {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                Text(
                                    "\(model.languageCode?.uppercased() ?? "ALL") • Speed \(model.speedScore)/10 • Accuracy \(model.accuracyScore)/10 • \(model.sizeLabel)"
                                )
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            voiceModelStatusLabel(for: model)
                            voiceModelActionButtons(for: model)
                        }

                        if let operation = appState.voiceModelOperationState(for: model) {
                            VoiceModelOperationProgressView(
                                operation: operation,
                                german: effectiveLanguage.embeddedInterfaceCode.hasPrefix("de")
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private func voiceModelStatusLabel(for model: VoiceModelDescriptor) -> some View {
        if let operation = appState.voiceModelOperationState(for: model) {
            switch operation {
            case .installing(let progress):
                Text(
                    text(
                        "Installiere \(progress.percentComplete) %",
                        "Installing \(progress.percentComplete)%"
                    )
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            case .removing:
                Text(text("Wird entfernt …", "Removing …"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(
                appState.isVoiceModelInstalled(model)
                    ? text("Installiert", "Installed")
                    : text("Nicht installiert", "Not installed")
            )
            .font(.footnote.weight(.medium))
            .foregroundStyle(
                appState.isVoiceModelInstalled(model) ? .secondary : .tertiary)
        }
    }

    @ViewBuilder
    private func voiceModelActionButtons(for model: VoiceModelDescriptor) -> some View {
        if appState.isVoiceModelBusy(model) {
            EmptyView()
        } else if appState.isVoiceModelInstalled(model) {
            Button(text("Als Standard verwenden", "Use as default")) {
                appState.setSelectedVoiceModel(model)
            }
            .liquidGlassSecondaryButtonStyle()
            .disabled(appState.selectedVoiceModelID == model.id)

            if model.installState != .bundled {
                Button(role: .destructive) {
                    appState.removeVoiceModel(model)
                } label: {
                    Text(text("Entfernen", "Remove"))
                }
                .liquidGlassDestructiveButtonStyle()
            }
        } else {
            Button(text("Installieren", "Install")) {
                appState.installVoiceModel(model)
            }
            .liquidGlassPrimaryButtonStyle()
            .disabled(model.installState == .unavailable)
        }
    }

    @ViewBuilder
    var liveRewriteContent: some View {
        if matches([
            "anpassung",
            "anpassungsradius",
            "anpassen",
            "rückwirkung",
            "rückwirkend",
            "rückwirkungsbereich",
            "rueckwirkung",
            "rueckwirkend",
            "rueckwirkungsbereich",
            "rewrite",
            "kontext",
            "retroaktiv",
            "weit zurück",
            "live",
        ]) {
            LabeledContent {
                Picker(
                    text("Anpassungsradius", "Adjustment radius"),
                    selection: $appState.liveRewriteScope
                ) {
                    ForEach(LiveRewriteScope.allCases) { scope in
                        Text(
                            scope.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(scope)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 260)
                .disabled(!isLiveRewriteScopeApplicable)
            } label: {
                SettingsFieldLabel(
                    title: text("Anpassungsradius", "Adjustment radius"),
                    helpText: text(
                        "Wirkt nur, wenn „Live-Text einfügen“ aktiv ist und nicht „Nur Zwischenablage“ gewählt ist. Kleinere Bereiche sind stabiler. Größere Bereiche glätten stärker, dürfen aber weiter zurückliegende Wörter noch einmal anfassen.",
                        "Only applies when Insert live text is on and delivery is not clipboard-only. Smaller scopes are more stable. Larger scopes smooth more aggressively but may revisit words further back."
                    )
                )
            }
        }
    }

    @ViewBuilder
    var dictationDeliveryContent: some View {
        if matches([
            "sprache", "language", "qualität", "quality", "streaming", "clipboard",
            "zwischenablage", "insert", "translation", "übersetzung", "uebersetzung", "paste",
            "auto-send", "keypress",
        ]) {
            LabeledContent {
                Picker(
                    text("Finales Ergebnis", "Final result"),
                    selection: $appState.finalResultDeliveryMode
                ) {
                    Text(text("In Textfeld einfügen", "Insert into text field")).tag(
                        FinalResultDeliveryMode.insert)
                    Text(text("Nur in Zwischenablage kopieren", "Copy to clipboard only")).tag(
                        FinalResultDeliveryMode.clipboardOnly)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 220)
            } label: {
                SettingsFieldLabel(
                    title: text("Finales Ergebnis", "Final result"),
                    helpText: text(
                        "Legt fest, wie das abgeschlossene Diktat ausgeliefert wird: direkt ins aktive Textfeld oder nur über die Zwischenablage.",
                        "Controls how the finished dictation is delivered: directly into the active text field or only through the clipboard."
                    )
                )
            }

            Toggle(isOn: $appState.streamingEnabled) {
                SettingsFieldLabel(
                    title: text("Live-Text einfügen", "Insert live text"),
                    helpText: text(
                        "Zeigt laufende Zwischenergebnisse direkt im Zieltextfeld an, solange gestreamt wird.",
                        "Shows live intermediate results directly in the target text field while streaming is active."
                    )
                )
            }
            .disabled(
                appState.finalResultDeliveryMode == .clipboardOnly
                    || !appState.dictationCapability.allowsDirectInsertion)

            Text(
                text(
                    "Für die beste Endqualität: Live-Text deaktivieren und die finale Formatierung aktiviert lassen. Das gibt ASR und AI mehr Ruhe für den letzten Pass.",
                    "For the best final quality, disable live text and keep final formatting enabled. That gives ASR and AI more headroom for the last pass."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Toggle(isOn: $appState.muteMusicWhileDictating) {
                SettingsFieldLabel(
                    title: text(
                        "Musik während des Diktats pausieren", "Pause music while dictating"),
                    helpText: text(
                        "Pausiert Apple Music und Spotify best-effort beim Start und setzt nur Player fort, die Wispr selbst pausiert hat.",
                        "Best-effort pauses Apple Music and Spotify on start and resumes only players that Wispr paused itself."
                    )
                )
            }

            Toggle(isOn: $appState.clipboardFallbackWhenNoTarget) {
                SettingsFieldLabel(
                    title: text(
                        "Wenn kein Textfeld aktiv ist: Ergebnis in Zwischenablage kopieren",
                        "If no text field is active: copy result to clipboard"),
                    helpText: text(
                        "Verwendet die Zwischenablage als Fallback, wenn macOS gerade kein direkt beschreibbares Textziel meldet.",
                        "Uses the clipboard as a fallback when macOS does not currently report a directly writable text target."
                    )
                )
            }
            .disabled(appState.finalResultDeliveryMode == .clipboardOnly)

            Toggle(isOn: $appState.autoSendAfterPaste) {
                SettingsFieldLabel(
                    title: text("Nach dem Einfügen automatisch senden", "Auto-send after paste"),
                    helpText: text(
                        "Sendet nach dem finalen Einfügen eine Eingabetaste (Return), auch wenn der Text direkt ins Feld geschrieben wurde – nicht nur bei Einfügen über die Zwischenablage. Nützlich in Chats oder Formularen.",
                        "Sends Return after final text is inserted, including when text is written directly into the field—not only when pasting from the clipboard. Useful in chats or forms."
                    )
                )
            }
            Toggle(isOn: $appState.restoreClipboardAfterPaste) {
                SettingsFieldLabel(
                    title: text(
                        "Zwischenablage nach dem Einfügen wiederherstellen",
                        "Restore clipboard after paste"),
                    helpText: text(
                        "Stellt den vorherigen Inhalt der Zwischenablage nach dem finalen Einfügen wieder her.",
                        "Restores the previous clipboard contents after final insertion."
                    )
                )
            }
            Toggle(isOn: $appState.simulateKeypresses) {
                SettingsFieldLabel(
                    title: text("Tastatureingaben simulieren", "Simulate keypresses"),
                    helpText: text(
                        "Gilt nur für das finale Einfügen am Ende der Aufnahme und für Einfüge-Fallbacks per Tastatur. Laufende Live-Zwischenergebnisse werden weiterhin direkt im Zieltextfeld aktualisiert.",
                        "Applies only to final insertion at the end of recording and to keyboard-based fallbacks. Live streaming updates still go directly into the target field."
                    )
                )
            }

            if !appState.dictationCapability.allowsDirectInsertion {
                Text(
                    text(
                        "Ohne Bedienungshilfen startet die Aufnahme weiterhin, aber direktes Einfügen bleibt deaktiviert.",
                        "Without Accessibility, recording still starts, but direct insertion remains disabled."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
