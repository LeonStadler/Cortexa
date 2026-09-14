import AIProcessingCore
import AppKit
import SwiftUI

extension SettingsView {
    private func selectedRemoteProviderBinding<T>(
        _ keyPath: WritableKeyPath<AIRemoteProviderConfiguration, T>,
        default defaultValue: T
    ) -> Binding<T> {
        Binding(
            get: {
                appState.selectedRemoteProvider?[keyPath: keyPath] ?? defaultValue
            },
            set: { newValue in
                appState.updateSelectedRemoteProvider { provider in
                    provider[keyPath: keyPath] = newValue
                }
            }
        )
    }

    @ViewBuilder
    var aiProviderContent: some View {
        if aiHasMatches {
            VStack(alignment: .leading, spacing: 14) {
                DisclosureGroup(
                    isExpanded: $addProviderDisclosureExpanded,
                    content: {
                        providerPresetGrid
                        providerPresetAddConfirmationRow
                    },
                    label: {
                        Text(text("Anbieter hinzufügen", "Add provider"))
                            .font(.headline)
                    }
                )

                if !appState.remoteProviders.isEmpty {
                    Text(text("Aktiver Anbieter", "Active provider"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    providerSelectionRow
                    providerEditorCard
                }
            }
            .onAppear {
                appState.refreshAllRemoteProviderModels()
            }
        }
    }

    @ViewBuilder
    private var providerPresetAddConfirmationRow: some View {
        if let preset = selectedRemoteProviderPreset {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    text(
                        "Ausgewählt: \(preset.localizedDisplayName(interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)). Mit „Hinzufügen“ in die Liste übernehmen.",
                        "Selected: \(preset.localizedDisplayName(interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)). Use “Add” to add it to the list."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(text("Abbrechen", "Cancel")) {
                        selectedRemoteProviderPreset = nil
                    }
                    .liquidGlassSecondaryButtonStyle()
                    Button(text("Hinzufügen", "Add")) {
                        appState.addRemoteProvider(preset: preset)
                        selectedRemoteProviderPreset = nil
                    }
                    .liquidGlassPrimaryButtonStyle()
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var providerPresetGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            providerPresetGroup(
                title: text("Cloud-APIs", "Cloud APIs"),
                presets: [
                    .openRouter, .openAI, .groq, .mistral, .deepSeek, .togetherAI, .fireworksAI,
                    .xAI,
                ]
            )

            providerPresetGroup(
                title: text("Lokale Server", "Local servers"),
                presets: [.ollama, .lmStudio]
            )

            providerPresetGroup(
                title: text("Eigenes Setup", "Custom setup"),
                presets: [.customOpenAICompatible]
            )
        }
    }

    @ViewBuilder
    private func providerPresetGroup(title: String, presets: [AIRemoteProviderPreset]) -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(presets) { preset in
                    Button {
                        selectedRemoteProviderPreset = preset
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.localizedDisplayName(interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode))
                                Text(providerPresetDescription(for: preset))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedRemoteProviderPreset == preset {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedRemoteProviderPreset == preset ? .isSelected : [])
                    if preset.id != presets.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func providerPresetDescription(for preset: AIRemoteProviderPreset) -> String {
        switch preset {
        case .openRouter:
            return text(
                "Viele Modelle über einen zentralen Zugang.",
                "Many models through one unified gateway.")
        case .openAI:
            return text("Offizielle OpenAI-API.", "Official OpenAI API.")
        case .groq:
            return text(
                "Schnelle OpenAI-kompatible Cloud-API.", "Fast OpenAI-compatible cloud API.")
        case .mistral:
            return text(
                "Mistral über die OpenAI-kompatible Schnittstelle.",
                "Mistral via the OpenAI-compatible surface.")
        case .deepSeek:
            return text("DeepSeek mit Standard-Endpunkten.", "DeepSeek with standard endpoints.")
        case .togetherAI:
            return text("Modellvielfalt für Remote-Setups.", "Model variety for remote setups.")
        case .fireworksAI:
            return text(
                "Gehostete Modelle mit klaren Endpunkten.", "Hosted models with clear endpoints.")
        case .xAI:
            return text("xAI über OpenAI-kompatible Calls.", "xAI over OpenAI-compatible calls.")
        case .ollama:
            return text("Lokale Modelle ohne API-Key.", "Local models without an API key.")
        case .lmStudio:
            return text("Lokaler Server für eigene Modelle.", "Local server for your own models.")
        case .customOpenAICompatible:
            return text(
                "Eigene Base-URL und Endpunkte definieren.",
                "Define your own base URL and endpoints.")
        }
    }

    @ViewBuilder
    private var providerSelectionRow: some View {
        LabeledContent(text("Aktiver Anbieter", "Active provider")) {
            Picker(
                text("Aktiver Anbieter", "Active provider"),
                selection: Binding(
                    get: { appState.selectedRemoteProviderID ?? "" },
                    set: { appState.selectedRemoteProviderID = $0.isEmpty ? nil : $0 }
                )
            ) {
                ForEach(appState.remoteProviders) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .settingsFormMenuPickerSlot(minWidth: 240)
        }
    }

    @ViewBuilder
    private var providerEditorCard: some View {
        if let provider = appState.selectedRemoteProvider {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(provider.displayName)
                            .font(.headline)
                        Text(
                            provider.preset.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        text("Aktiv", "Enabled"),
                        isOn: selectedRemoteProviderBinding(\.isEnabled, default: false)
                    )
                    .toggleStyle(.switch)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text(text("Name", "Name"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            text("Name", "Name"),
                            text: selectedRemoteProviderBinding(\.displayName, default: "")
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("Base URL", "Base URL"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            "", text: selectedRemoteProviderBinding(\.baseURLString, default: "")
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("Modelle", "Models"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            text: selectedRemoteProviderBinding(\.modelsPath, default: "/models")
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("Text-API", "Text API"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            text: selectedRemoteProviderBinding(
                                \.chatCompletionsPath, default: "/chat/completions")
                        )
                        .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text(text("API-Key nötig", "API key required"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Toggle(
                            text("Ja", "Yes"),
                            isOn: selectedRemoteProviderBinding(\.requiresAPIKey, default: true)
                        )
                        .toggleStyle(.switch)
                    }

                    GridRow {
                        Text(text("API-Key", "API key"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        SecureField("", text: $appState.remoteProviderAPIKeyDraft)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack(spacing: 8) {
                    Button(text("Speichern", "Save")) {
                        appState.saveSelectedRemoteProvider()
                    }
                    .liquidGlassPrimaryButtonStyle()

                    Button(text("Modelle aktualisieren", "Refresh models")) {
                        appState.refreshSelectedRemoteProviderModels()
                    }
                    .liquidGlassSecondaryButtonStyle()

                    Spacer()

                    Button(role: .destructive) {
                        appState.removeSelectedRemoteProvider()
                    } label: {
                        Text(text("Anbieter entfernen", "Remove provider"))
                    }
                    .liquidGlassDestructiveButtonStyle()
                }

                if !provider.discoveredModels.isEmpty {
                    Text(
                        text(
                            "Verfügbare Modelle: \(provider.discoveredModels.count)",
                            "Available models: \(provider.discoveredModels.count)"
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
