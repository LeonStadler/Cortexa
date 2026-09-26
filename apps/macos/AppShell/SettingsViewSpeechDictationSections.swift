import ASRCore
import SwiftUI

enum SpeechModelProviderFilter {
    static let allProvidersID = "__all_providers__"
}

enum SpeechModelAvailabilityFilter: String, CaseIterable, Identifiable {
    case all
    case installed
    case notInstalled

    var id: String { rawValue }

    func localizedDisplayName(language: AppLanguage) -> String {
        switch self {
        case .all:
            return language.text("Alle", "All")
        case .installed:
            return language.text("Installiert", "Installed")
        case .notInstalled:
            return language.text("Download", "Download")
        }
    }
}

enum SpeechModelLanguageFilter: String, CaseIterable, Identifiable {
    case all
    case multilingual
    case englishOnly

    var id: String { rawValue }

    func localizedDisplayName(language: AppLanguage) -> String {
        switch self {
        case .all:
            return language.text("Alle Sprachen", "All languages")
        case .multilingual:
            return language.text("Mehrsprachig", "Multilingual")
        case .englishOnly:
            return language.text("Nur Englisch", "English only")
        }
    }
}

extension SettingsView {
    @ViewBuilder
    var speechModelSelectionContent: some View {
        if speechHasMatches {
            LabeledContent {
                if appState.visibleSelectableVoiceModels.isEmpty {
                    Text(text("Keine Modelle erkannt", "No models detected"))
                        .foregroundStyle(.secondary)
                } else {
                    Picker(
                        text("Voice-Modell", "Voice model"),
                        selection: voiceModelSelectionBinding
                    ) {
                        ForEach(appState.visibleSelectableVoiceModels) { model in
                            Text(voiceModelPickerTitle(for: model)).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .settingsFormMenuPickerSlot(minWidth: 240)
                    .confirmationDialog(
                        text("Modell herunterladen?", "Download model?"),
                        isPresented: pendingVoiceModelInstallDialogBinding
                    ) {
                        Button(text("Download und auswählen", "Download and choose")) {
                            if let model = pendingVoiceModelForInstallation {
                                appState.installVoiceModel(model)
                                pendingVoiceModelForInstallation = nil
                            }
                        }
                        Button(text("Abbrechen", "Cancel"), role: .cancel) {}
                    } message: {
                        Text(
                            pendingVoiceModelForInstallation.map(voiceModelInstallationMessage)
                                ?? ""
                        )
                    }
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
                .disabled(appState.selectedVoiceModel?.runtimeID == "nemo-speech")
            } label: {
                SettingsFieldLabel(
                    title: text("Qualitätsprofil", "Quality profile"),
                    helpText: text(
                        "Steuert Laufzeitparameter wie Beam-Search, Chunking und Threads.",
                        "Controls runtime parameters like beam search, chunking, and threads."
                    )
                )
            }

            Text(qualityProfileExplanation)
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

    private var qualityProfileExplanation: String {
        if appState.selectedVoiceModel?.runtimeID == "nemo-speech" {
            return text(
                "Parakeet verwendet feste Einstellungen der NeMo-Runtime. Das Qualitätsprofil gilt derzeit nur für Whisper und ist deshalb deaktiviert.",
                "Parakeet uses fixed NeMo runtime settings. The quality profile currently applies only to Whisper, so it is disabled."
            )
        }
        return text(
            "Auto passt das Preset an Gerät und Laufzeit an. Schnell priorisiert Reaktionszeit, Ausgeglichen balanciert Stabilität und Tempo, Präzise investiert mehr in die finale Erkennung.",
            "Auto adapts the preset to the device and runtime. Fast prioritizes responsiveness, Balanced trades speed for stability, and Accurate spends more on the final recognition pass."
        )
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
                appState.speechTranslationUnavailableReason
                    ?? text(
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
            LabeledContent(text("Suche", "Search")) {
                modelSearchField
            }

            LabeledContent(text("Status", "Status")) {
                modelStatusFilter
            }

            LabeledContent(text("Anbieter", "Provider")) {
                modelProviderFilter
            }

            LabeledContent(text("Sprache", "Language")) {
                modelLanguageFilter
            }

            if filteredVoiceModelsForManagement.isEmpty {
                ContentUnavailableView {
                    Label(
                        text("Keine passenden Modelle", "No matching models"),
                        systemImage: "magnifyingglass"
                    )
                } description: {
                    Text(text(
                        "Passe die Suche oder Filter an.",
                        "Adjust your search or filters."
                    ))
                }
            } else {
                ForEach(filteredVoiceModelsForManagement) { model in
                    voiceModelManagementRow(for: model)
                }
            }
        }
    }

    private var modelSearchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("", text: $speechModelSearchText)
                .textFieldStyle(.plain)
                .accessibilityLabel(text("Modelle suchen", "Search models"))

            if !speechModelSearchText.isEmpty {
                Button {
                    speechModelSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(text("Suche löschen", "Clear search"))
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }

    private var modelStatusFilter: some View {
        Picker(text("Modellstatus", "Model status"), selection: $speechModelAvailabilityFilter) {
            ForEach(SpeechModelAvailabilityFilter.allCases) { filter in
                Text(filter.localizedDisplayName(language: effectiveLanguage)).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var modelProviderFilter: some View {
        Picker(text("Modellanbieter", "Model provider"), selection: $speechModelProviderFilter) {
            Text(text("Alle Anbieter", "All providers"))
                .tag(SpeechModelProviderFilter.allProvidersID)
            ForEach(modelManagementProviders) { provider in
                Text(provider.displayName).tag(provider.id)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var modelLanguageFilter: some View {
        Picker(text("Sprache", "Language"), selection: $speechModelLanguageFilter) {
            ForEach(SpeechModelLanguageFilter.allCases) { filter in
                Text(filter.localizedDisplayName(language: effectiveLanguage)).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private func voiceModelManagementRow(for model: VoiceModelDescriptor) -> some View {
        LabeledContent {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    voiceModelStatusLabel(for: model)
                    voiceModelActionButtons(for: model)
                }
                VStack(alignment: .trailing, spacing: 6) {
                    voiceModelStatusLabel(for: model)
                    voiceModelActionButtons(for: model)
                }
            }

            if let operation = voiceModelOperationStore.states[model.id] {
                VoiceModelOperationProgressView(
                    operation: operation,
                    german: effectiveLanguage.embeddedInterfaceCode.hasPrefix("de"),
                    onCancel: { appState.cancelVoiceModelInstallation(model) }
                )
            }
        } label: {
            voiceModelSummary(for: model)
        }
    }

    private var filteredVoiceModelsForManagement: [VoiceModelDescriptor] {
        let query = speechModelSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return appState.allVoiceModels.filter { model in
            let matchesProvider = speechModelProviderFilter == SpeechModelProviderFilter.allProvidersID
                || model.providerID == speechModelProviderFilter
            let matchesAvailability: Bool = {
                switch speechModelAvailabilityFilter {
                case .all:
                    return true
                case .installed:
                    return appState.isVoiceModelInstalled(model)
                case .notInstalled:
                    return !appState.isVoiceModelInstalled(model)
                }
            }()
            let matchesLanguage: Bool = {
                switch speechModelLanguageFilter {
                case .all:
                    return true
                case .multilingual:
                    return model.languageCode == nil
                case .englishOnly:
                    return model.languageCode == DictationLanguage.english.rawValue
                }
            }()
            let matchesSearch = query.isEmpty
                || model.displayName.lowercased().contains(query)
                || model.id.lowercased().contains(query)
                || model.providerID.lowercased().contains(query)
                || (modelManagementProviders.first(where: { $0.id == model.providerID })?.displayName
                    .lowercased().contains(query) ?? false)
                || (model.languageCode?.lowercased().contains(query) ?? false)
            return matchesProvider && matchesAvailability && matchesLanguage && matchesSearch
        }
    }

    private var modelManagementProviders: [VoiceProviderDescriptor] {
        let registeredProviders = appState.voiceProviders
        let registeredIDs = Set(registeredProviders.map(\.id))
        let modelProviderIDs = Set(appState.allVoiceModels.map(\.providerID))
        let unregisteredProviders = modelProviderIDs.subtracting(registeredIDs).sorted().map {
            VoiceProviderDescriptor(
                id: $0,
                displayName: $0,
                summary: "",
                isAvailable: false
            )
        }
        return registeredProviders + unregisteredProviders
    }

    private func voiceModelSummary(for model: VoiceModelDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.displayName)
            Text("\(model.languageCode?.uppercased() ?? "ALL") • Speed \(model.speedScore)/10 • Accuracy \(model.accuracyScore)/10 • \(model.sizeLabel)")
                .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            if model.providerID == VoiceProviderID.nvidiaParakeet.rawValue {
                Link("NVIDIA Parakeet TDT v3 · CC BY 4.0", destination: URL(string: "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3")!)
                    .font(.footnote)
            }
        }
    }

    private var voiceModelSelectionBinding: Binding<String> {
        Binding(
            get: { appState.selectedVoiceModelID },
            set: { newValue in
                guard let model = appState.allVoiceModels.first(where: { $0.id == newValue })
                else { return }
                if appState.isVoiceModelInstalled(model) {
                    appState.setSelectedVoiceModel(model)
                } else if model.installState != .unavailable {
                    pendingVoiceModelForInstallation = model
                }
            }
        )
    }

    private var pendingVoiceModelInstallDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingVoiceModelForInstallation != nil },
            set: { isPresented in
                if !isPresented {
                    pendingVoiceModelForInstallation = nil
                }
            }
        )
    }

    private func voiceModelPickerTitle(for model: VoiceModelDescriptor) -> String {
        let status: String
        if appState.isVoiceModelBusy(model) {
            status = text("lädt", "busy")
        } else if appState.isVoiceModelInstalled(model) {
            status = text("installiert", "installed")
        } else if model.installState == .unavailable {
            status = text("nicht verfügbar", "unavailable")
        } else {
            status = text("Download", "download")
        }
        return "\(model.displayName) · \(status)"
    }

    private func voiceModelInstallationMessage(for model: VoiceModelDescriptor) -> String {
        let language = model.languageCode?.uppercased() ?? text("mehrsprachig", "multilingual")
        let translation = model.supportsTranslationToEnglish ? text("ja", "yes") : text("nein", "no")
        if model.providerID == VoiceProviderID.nvidiaParakeet.rawValue,
            VoiceModelInstaller.resolveNemoSpeechCLI() == nil {
            return text(
                "\(model.displayName)\nSprache: \(language)\nGröße: \(model.sizeLabel)\nÜbersetzung: \(translation)\n\nCortexa richtet zuerst die passende NeMo-Speech-Runtime ein und lädt danach das Modell herunter.",
                "\(model.displayName)\nLanguage: \(language)\nSize: \(model.sizeLabel)\nTranslation: \(translation)\n\nCortexa will first install the compatible NeMo-Speech runtime, then download the model."
            )
        }
        return text(
            "\(model.displayName)\nSprache: \(language)\nGröße: \(model.sizeLabel)\nÜbersetzung: \(translation)\n\nDas Modell wird heruntergeladen und danach automatisch ausgewählt.",
            "\(model.displayName)\nLanguage: \(language)\nSize: \(model.sizeLabel)\nTranslation: \(translation)\n\nThe model will download and then be selected automatically."
        )
    }

    @ViewBuilder
    private func voiceModelStatusLabel(for model: VoiceModelDescriptor) -> some View {
        if let operation = voiceModelOperationStore.states[model.id] {
            switch operation {
            case .installing:
                EmptyView()
            case .removing:
                Text(text("Wird entfernt …", "Removing …"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        } else if appState.isVoiceModelInstalled(model) {
            if model.installState == .requiredFirstRun {
                Text(text("Erforderlich für den Betrieb", "Required for operation"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Text(text("Installiert", "Installed"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(text("Nicht installiert", "Not installed"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func voiceModelActionButtons(for model: VoiceModelDescriptor) -> some View {
        if appState.isVoiceModelBusy(model) {
            EmptyView()
        } else if appState.isVoiceModelInstalled(model) {
            if model.runtimeID == "nemo-speech",
                appState.voiceProviders.first(where: { $0.id == model.providerID })?.isAvailable != true {
                Button(text("Runtime installieren", "Install runtime")) {
                    appState.installVoiceModel(model)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            Button(text("Als Standard verwenden", "Use as default")) {
                appState.setSelectedVoiceModel(model)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(
                appState.selectedVoiceModelID == model.id
                    || appState.voiceProviders.first(where: { $0.id == model.providerID })?.isAvailable
                        != true)

            if model.installState != .bundled && model.installState != .requiredFirstRun {
                Button(role: .destructive) {
                    appState.removeVoiceModel(model)
                } label: {
                    Text(text("Entfernen", "Remove"))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } else {
            Button(text("Installieren", "Install")) {
                appState.installVoiceModel(model)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
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
                    || !appState.selectedVoiceModelSupportsLiveTranscription
                    || !appState.dictationCapability.allowsDirectInsertion)

            if !appState.selectedVoiceModelSupportsLiveTranscription {
                Text(text(
                    "Parakeet verarbeitet die Aufnahme erst nach dem Stoppen; Live-Text und Live-AI bleiben daher ausgeschaltet.",
                    "Parakeet processes the recording after you stop; live text and live AI therefore stay off."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

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
