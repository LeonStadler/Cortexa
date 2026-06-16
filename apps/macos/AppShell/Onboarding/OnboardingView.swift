import ASRCore
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: MacAppState
    let onboardingStore: OnboardingStore
    @ObservedObject var coordinator: OnboardingCoordinator

    @AppStorage("wispr.settings.appLanguage") private var appLanguageRawValue = AppLanguage.system
        .rawValue

    private var effectiveLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue)?.contentLanguage
            ?? AppLanguage.resolvedFromSystemPreferences()
    }

    private func text(_ german: String, _ english: String) -> String {
        effectiveLanguage.text(german, english)
    }

    private var standardModel: VoiceModelDescriptor? {
        appState.voiceModels.first(where: { $0.id == LocalVoiceModelCatalog.defaultModelID })
    }

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stepContent
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            navigationBar
                .padding(20)
        }
        .frame(minWidth: 480, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appState.refreshVoiceModelCatalog()
            appState.refreshPermissionStatesWithStabilization()
            startStandardModelDownloadIfNeeded()
        }
        .onChange(of: coordinator.currentStep) { _, newStep in
            if newStep == .standardModel {
                startStandardModelDownloadIfNeeded()
            }
        }
    }

    private var stepIndicator: some View {
        HStack {
            Text(
                text(
                    "Schritt \(coordinator.currentStep.stepNumber) von \(OnboardingStep.totalSteps)",
                    "Step \(coordinator.currentStep.stepNumber) of \(OnboardingStep.totalSteps)"
                )
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            Spacer()
            ProgressView(
                value: Double(coordinator.currentStep.stepNumber),
                total: Double(OnboardingStep.totalSteps)
            )
            .progressViewStyle(.linear)
            .frame(width: 120)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch coordinator.currentStep {
        case .welcome:
            welcomeStep
        case .permissions:
            permissionsStep
        case .standardModel:
            standardModelStep
        case .basics:
            basicsStep
        case .done:
            doneStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(text("Willkommen bei WisprLocal", "Welcome to WisprLocal"))
                    .font(.title2.weight(.semibold))
            } icon: {
                Image(systemName: "waveform.circle.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
            }

            Text(
                text(
                    "WisprLocal ist ein offline-fähiger Diktier-Assistent für die Menüleiste. Deine Sprache wird lokal auf dem Mac transkribiert — ohne Cloud.",
                    "WisprLocal is an offline-capable dictation assistant for your menu bar. Your speech is transcribed locally on your Mac — no cloud required."
                )
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                onboardingBullet(
                    "mic.fill",
                    text("Menüleisten-Steuerung", "Menu bar control"),
                    text(
                        "Starte und stoppe Diktate direkt aus der Menüleiste.",
                        "Start and stop dictation from the menu bar."
                    )
                )
                onboardingBullet(
                    "lock.shield.fill",
                    text("Lokal & privat", "Local & private"),
                    text(
                        "Spracherkennung läuft mit whisper.cpp auf deinem Gerät.",
                        "Speech recognition runs with whisper.cpp on your device."
                    )
                )
                onboardingBullet(
                    "arrow.down.circle.fill",
                    text("Einmaliges Modell-Setup", "One-time model setup"),
                    text(
                        "Das Standard-Sprachmodell wird beim ersten Start heruntergeladen.",
                        "The standard speech model downloads on first launch."
                    )
                )
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text("Berechtigungen", "Permissions"))
                .font(.title3.weight(.semibold))

            Text(
                text(
                    "Für Diktat wird mindestens Mikrofonzugriff benötigt. Bedienungshilfen ermöglichen direktes Einfügen in Textfelder.",
                    "Dictation requires microphone access at minimum. Accessibility enables direct insertion into text fields."
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            permissionRow(
                title: text("Mikrofon", "Microphone"),
                status: appState.microphonePermissionStatus,
                required: true,
                requestAction: { appState.requestMicrophoneAccessFromSettings() },
                settingsAction: { appState.openMicrophoneSettings() }
            )

            permissionRow(
                title: text("Bedienungshilfen", "Accessibility"),
                status: appState.accessibilityPermissionStatus,
                required: false,
                requestAction: { appState.requestAccessibilityAccessFromSettings() },
                settingsAction: { appState.openAccessibilitySettings() }
            )

            if appState.microphonePermissionStatus != .granted {
                PermissionRecoveryBanner(
                    title: text("Mikrofon erforderlich", "Microphone required"),
                    message: text(
                        "Ohne Mikrofonberechtigung kann WisprLocal keine Sprache aufnehmen.",
                        "Without microphone permission WisprLocal cannot capture speech."
                    ),
                    actionTitle: text("Mikrofon erlauben", "Allow microphone"),
                    action: { appState.requestMicrophoneAccessFromSettings() }
                )
            } else if appState.accessibilityPermissionStatus != .granted {
                PermissionRecoveryBanner(
                    title: text("Eingeschränkter Modus", "Limited mode"),
                    message: text(
                        "Ohne Bedienungshilfen bleiben Transkripte im Verlauf oder in der Zwischenablage.",
                        "Without accessibility, transcripts stay in history or the clipboard."
                    ),
                    actionTitle: text("Bedienungshilfen öffnen", "Open Accessibility"),
                    action: { appState.openAccessibilitySettings() }
                )
            }
        }
    }

    private var standardModelStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text("Standard-Sprachmodell", "Standard speech model"))
                .font(.title3.weight(.semibold))

            if let standardModel {
                Text(
                    text(
                        "Das Modell „\(standardModel.displayName)“ (\(standardModel.sizeLabel)) ist für den Betrieb erforderlich und wird jetzt heruntergeladen.",
                        "The “\(standardModel.displayName)” model (\(standardModel.sizeLabel)) is required and will download now."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if let operation = appState.voiceModelOperationState(for: standardModel) {
                    VoiceModelOperationProgressView(
                        operation: operation,
                        german: effectiveLanguage.embeddedInterfaceCode.hasPrefix("de")
                    )
                } else if appState.isStandardModelInstalled {
                    Label {
                        Text(text("Modell installiert", "Model installed"))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline.weight(.medium))
                } else {
                    ProgressView()
                    Text(text("Download wird gestartet …", "Starting download …"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text("Grundlagen", "Basics"))
                .font(.title3.weight(.semibold))

            LabeledContent(text("Sprache", "Language")) {
                Picker(text("Sprache", "Language"), selection: $appState.selectedLanguage) {
                    ForEach(DictationLanguage.allCases.filter { $0 != .auto }) { language in
                        Text(
                            language.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Toggle(
                text("Live-Text einfügen", "Insert live text"),
                isOn: $appState.streamingEnabled
            )

            Picker(
                text("Finales Ergebnis", "Final result"),
                selection: $appState.finalResultDeliveryMode
            ) {
                Text(text("In Textfeld einfügen", "Insert into text field")).tag(
                    FinalResultDeliveryMode.insert)
                Text(text("Nur Zwischenablage", "Clipboard only")).tag(
                    FinalResultDeliveryMode.clipboardOnly)
            }
            .pickerStyle(.radioGroup)

            LabeledContent(text("Kurzbefehl", "Shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.selectedHotkey,
                    label: text("Diktier-Kurzbefehl", "Dictation shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 240)
            }
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(text("Alles bereit!", "All set!"))
                    .font(.title3.weight(.semibold))
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            Text(
                text(
                    "WisprLocal ist eingerichtet. Du findest die Steuerung in der Menüleiste — starte dein erstes Diktat mit \(appState.selectedHotkey.displayName).",
                    "WisprLocal is set up. Control it from the menu bar — start your first dictation with \(appState.selectedHotkey.displayName)."
                )
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var navigationBar: some View {
        HStack {
            if coordinator.currentStep != .welcome {
                Button(text("Zurück", "Back")) {
                    coordinator.goToPreviousStep()
                }
                .liquidGlassSecondaryButtonStyle()
            }

            Spacer()

            if coordinator.currentStep == .done {
                Button(text("Los geht's", "Get started")) {
                    coordinator.finish(onboardingStore: onboardingStore, appState: appState)
                }
                .liquidGlassPrimaryButtonStyle()
                .keyboardShortcut(.defaultAction)
            } else {
                Button(text("Weiter", "Continue")) {
                    if coordinator.currentStep == .basics {
                        coordinator.goToNextStep()
                    } else {
                        coordinator.goToNextStep()
                    }
                }
                .liquidGlassPrimaryButtonStyle()
                .disabled(!coordinator.canProceed(appState: appState))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func onboardingBullet(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func permissionRow(
        title: String,
        status: PermissionStatus,
        required: Bool,
        requestAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    if required {
                        Text(text("Pflicht", "Required"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(localizedPermissionStatus(status))
                    .font(.caption)
                    .foregroundStyle(status.color)
            }
            Spacer()
            if status != .granted {
                Button(text("Erlauben", "Allow"), action: requestAction)
                    .liquidGlassSecondaryButtonStyle()
                    .controlSize(.small)
                Button(text("Einstellungen", "Settings"), action: settingsAction)
                    .liquidGlassSecondaryButtonStyle()
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func localizedPermissionStatus(_ status: PermissionStatus) -> String {
        switch (effectiveLanguage.embeddedInterfaceCode, status) {
        case ("en", .granted):
            return "Granted"
        case ("en", .denied):
            return "Denied"
        case ("en", .notDetermined):
            return "Not checked yet"
        case ("en", .restricted):
            return "Restricted"
        default:
            return status.label
        }
    }

    private func startStandardModelDownloadIfNeeded() {
        guard coordinator.currentStep == .standardModel,
            !appState.isStandardModelInstalled,
            !appState.isStandardModelDownloadBusy,
            let standardModel
        else { return }
        appState.installVoiceModel(standardModel)
    }
}
