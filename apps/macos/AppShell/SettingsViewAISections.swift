import AIProcessingCore
import AppKit
import SwiftUI

extension SettingsView {
    @ViewBuilder
    var aiProcessingContent: some View {
        if aiHasMatches {
            Toggle(
                text("AI-Verarbeitung aktivieren", "Enable AI processing"),
                isOn: $appState.aiProcessingEnabled
            )
            .disabled(appState.selectedAIModel?.availability.isAvailable != true)

            if !appState.aiProcessingEnabled {
                Text(
                    text(
                        "Richte weiter unten Anbieter und Modell ein, dann aktiviere die Verarbeitung. In der Menüleiste erscheinen LLM und Feinsteuerung erst nach Aktivierung.",
                        "Configure a provider and model below, then enable processing. The menu bar shows the LLM and fine controls only after processing is enabled."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if appState.aiProcessingEnabled {
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 8) {
                        Toggle(
                            text("Inhaltsstreaming", "Content streaming"),
                            isOn: $appState.aiProcessingApplyDuringLiveInsertion
                        )
                        .disabled(!appState.effectiveStreamingEnabled)

                        Toggle(
                            text("Endergebnis einfügen", "Insert final result"),
                            isOn: $appState.aiProcessingApplyToFinalResult
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } label: {
                    SettingsFieldLabel(
                        title: text("AI anwenden bei", "Apply AI for"),
                        helpText: text(
                            "Steuert, ob das Modell schon auf Live-Zwischenergebnisse, erst auf das finale Ergebnis oder auf beides angewendet wird.",
                            "Controls whether the model is applied to live intermediate text, only to the final result, or to both."
                        )
                    )
                }
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                LabeledContent {
                    VStack(alignment: .trailing, spacing: 8) {
                        Toggle(
                            text("Stil / Ton", "Style / Tone"),
                            isOn: $appState.aiTaskToneEnabled
                        )
                        Toggle(
                            text("Anrede", "Salutation"),
                            isOn: $appState.aiTaskSalutationEnabled
                        )
                        Toggle(
                            text("Format / Modus", "Format / Mode"),
                            isOn: $appState.aiTaskFormatEnabled
                        )
                        Toggle(
                            text("Bereinigen", "Clean up"),
                            isOn: $appState.aiTaskCleanupEnabled
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } label: {
                    SettingsFieldLabel(
                        title: text("AI-Aufgaben", "AI tasks"),
                        helpText: text(
                            "Reihenfolge wie in der Menüleiste: Stil, Anrede, Format, Bereinigung. Kombinierbar; „Wie gesprochen“ bei Format oder Stil/Anrede bedeutet: kein Zusatzaufwand in dieser Dimension.",
                            "Same order as the menu bar: style, salutation, format, cleanup. “As spoken” for format or style/salutation means no extra work in that dimension."
                        )
                    )
                }
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                if appState.aiShowsWritingStyleControls {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 4) {
                            Picker(
                                text("Stil / Ton", "Style / Tone"),
                                selection: $appState.aiWritingStyle
                            ) {
                                ForEach(appState.availableAIWritingStyles) { style in
                                    Text(
                                        style.localizedDisplayName(
                                            interfaceLanguageCode: effectiveLanguage
                                                .embeddedInterfaceCode)
                                    ).tag(style)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .settingsFormMenuPickerSlot(minWidth: 220)

                            Text(
                                text("Ausgewählt:", "Selected:")
                                    + " "
                                    + appState.aiWritingStyle.localizedDisplayName(
                                        interfaceLanguageCode: effectiveLanguage
                                            .embeddedInterfaceCode)
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    } label: {
                        SettingsFieldLabel(
                            title: text("Stil / Ton", "Style / Tone"),
                            helpText: text(
                                "Zeigt nur Stile an, die zum gewählten Modus passen. Für Dokumentation oder wissenschaftliche Texte bleiben zum Beispiel nur sachliche Varianten übrig.",
                                "Shows only styles that fit the selected mode. For documentation or scientific text, only fitting formal variants remain available."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)
                }

                if appState.aiShowsSalutationControls {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 4) {
                            Picker(text("Anrede", "Salutation"), selection: $appState.aiSalutation) {
                                ForEach(AISalutation.allCases) { salutation in
                                    Text(
                                        salutation.localizedDisplayName(
                                            interfaceLanguageCode: effectiveLanguage
                                                .embeddedInterfaceCode)
                                    ).tag(salutation)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .settingsFormMenuPickerSlot(minWidth: 220)

                            Text(
                                text("Ausgewählt:", "Selected:")
                                    + " "
                                    + appState.aiSalutation.localizedDisplayName(
                                        interfaceLanguageCode: effectiveLanguage
                                            .embeddedInterfaceCode)
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    } label: {
                        SettingsFieldLabel(
                            title: text("Anrede", "Salutation"),
                            helpText: text(
                                "Die Anrede wird nur dort angeboten, wo sie sinnvoll ist, etwa bei E-Mails, Nachrichten oder WhatsApp.",
                                "Salutation is shown only where it makes sense, such as email, messages, or WhatsApp."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)
                }

                if appState.aiShowsModeControls {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 4) {
                            Picker(text("Formatierung", "Formatting"), selection: $appState.aiFormattingMode) {
                                ForEach(AIFormattingMode.allCases) { mode in
                                    Text(
                                        mode.localizedDisplayName(
                                            interfaceLanguageCode: effectiveLanguage
                                                .embeddedInterfaceCode)
                                    ).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .settingsFormMenuPickerSlot(minWidth: 220)

                            Text(
                                text("Ausgewählt:", "Selected:")
                                    + " "
                                    + appState.aiFormattingMode.localizedDisplayName(
                                        interfaceLanguageCode: effectiveLanguage
                                            .embeddedInterfaceCode)
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    } label: {
                        SettingsFieldLabel(
                            title: text("Formatierung", "Formatting"),
                            helpText: text(
                                "„Wie gesprochen“: keine aufgezwungene Struktur. „Automatische Formatierung“: aus dem Gesprochenen Listen und Absätze ableiten. Weitere Modi richten Text an E-Mail, Chat usw. aus.",
                                "“As spoken”: no imposed structure. “Automatic formatting” infers lists and paragraphs from speech. Other modes target email, chat, and similar shapes."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)
                }

                LabeledContent {
                    Picker(
                        text("Kontextbewusstsein", "Context awareness"),
                        selection: $appState.contextAwarenessMode
                    ) {
                        ForEach(ContextAwarenessMode.allCases) { mode in
                            Text(
                                mode.localizedDisplayName(
                                    interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode
                                )
                            )
                            .tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .settingsFormMenuPickerSlot(minWidth: 220)
                } label: {
                    SettingsFieldLabel(
                        title: text("Kontextbewusstsein", "Context awareness"),
                        helpText: text(
                            "Standard ist nur das Endergebnis. Live-Kontext bleibt optional und klein, damit Streaming stabil bleibt. Zusätzliche AI-Bereinigung verbessert den finalen Output weiter.",
                            "The default is final result only. Live context stays optional and small to keep streaming stable. Additional AI cleanup can further improve the final output."
                        )
                    )
                }
                .disabled(appState.selectedAIModel?.availability.isAvailable != true)

                if appState.aiTaskCleanupEnabled {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 6) {
                            Slider(
                                value: $appState.aiCleanupIntensity,
                                in: 0...1,
                                label: {
                                    Text(text("Bereinigungsstärke", "Cleanup strength"))
                                }
                            )
                            .frame(maxWidth: 280)
                            Text(
                                text(
                                    "Ganz links: praktisch keine Bereinigung (kein Modellaufruf, wenn sonst nichts aktiv ist). Rechts: kräftigere Korrektur.",
                                    "Far left: almost no cleanup (and no model call if nothing else is active). Right: stronger cleanup."
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 280, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    } label: {
                        SettingsFieldLabel(
                            title: text("Bereinigung", "Cleanup"),
                            helpText: text(
                                "Nur in den Einstellungen; steuert, wie aggressiv erkannt wird und korrigiert wird.",
                                "Settings only; controls how aggressively recognition issues are fixed."
                            )
                        )
                    }
                    .disabled(appState.selectedAIModel?.availability.isAvailable != true)
                }
            }
        }
    }

    @ViewBuilder
    var aiModelContent: some View {
        if aiHasMatches {
            LabeledContent {
                Picker(
                    text("Modell", "Model"),
                    selection: Binding(
                        get: { appState.selectedAIModelID ?? "" },
                        set: { appState.selectedAIModelID = $0.isEmpty ? nil : $0 }
                    )
                ) {
                    if appState.visibleAIModels.isEmpty {
                        Text(text("Keine Modelle erkannt", "No models detected")).tag("")
                    } else {
                        ForEach(appState.visibleAIModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 220)
            } label: {
                SettingsFieldLabel(
                    title: text("Modell", "Model"),
                    helpText: text(
                        "Zeigt alle aktuell erkannten lokalen und entfernten Modelle an, die Cortexa verwenden kann.",
                        "Shows all currently detected local and remote models that Cortexa can use."
                    )
                )
            }

            if appState.visibleAIModels.isEmpty {
                Text(
                    text(
                        "Es wurde aktuell kein AI-Modell erkannt.",
                        "There is currently no AI model available.")
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(appState.visibleAIModels, id: \AIModelDescriptor.id) {
                    (model: AIModelDescriptor) in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.body.weight(.semibold))
                        Text(model.providerKind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(
                            model.availability.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        )
                        .font(.footnote)
                        .foregroundStyle(
                            model.availability.isAvailable ? Color.secondary : Color.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
