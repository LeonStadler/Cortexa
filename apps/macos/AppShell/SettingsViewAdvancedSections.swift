import SwiftUI

extension SettingsView {
    @ViewBuilder
    var diagnosticsContent: some View {
        if matches(["diagnose", "diagnostics", "capability", "audit"]) {
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.capabilitySummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text(
                    text(
                        "Smoke-Test: Log-Datei artifacts/mac/dev-run.log (Projektroot).",
                        "Smoke test: log file artifacts/mac/dev-run.log (project root)."
                    )
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)

                Toggle(isOn: $appState.debugModeEnabled) {
                    SettingsFieldLabel(
                        title: text("Technische Protokollierung", "Technical logging"),
                        helpText: text(
                            "Erfasst zusätzliche Laufzeit- und Prozessdetails für die Diagnose. Nur einschalten, wenn du ein Problem genauer untersuchen willst.",
                            "Captures additional runtime and process details for diagnostics. Enable this only when you want to investigate a problem more closely."
                        )
                    )
                }

                if appState.debugModeEnabled {
                    DisclosureGroup(
                        content: {
                            Text(
                                appState.debugLogText.isEmpty
                                    ? text(
                                        "Noch keine Diagnoseprotokoll-Einträge erfasst.",
                                        "No diagnostic log entries captured yet.")
                                    : appState.debugLogText
                            )
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        },
                        label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    text(
                                        "Technisches Diagnoseprotokoll", "Technical diagnostic log")
                                )
                                Text(
                                    appState.debugLogText.isEmpty
                                        ? text(
                                            "Die technische Protokollierung ist aktiv. Neue Laufzeit- und Prozessereignisse erscheinen hier.",
                                            "Technical logging is active. New runtime and process events will appear here."
                                        )
                                        : appState.debugLogText.components(separatedBy: .newlines)
                                            .suffix(3).joined(separator: " ")
                                )
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .textSelection(.enabled)
                            }
                            .frame(minHeight: 38, alignment: .topLeading)
                        }
                    )
                }

                DisclosureGroup(
                    isExpanded: $diagnosticsExpanded,
                    content: {
                        Text(appState.diagnosticsText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    },
                    label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text("Letzte Diagnosezeilen", "Recent diagnostic lines"))
                            Text(
                                compressedDiagnosticsText.replacingOccurrences(of: "\n", with: " ")
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .textSelection(.enabled)
                        }
                        .frame(minHeight: 38, alignment: .topLeading)
                    }
                )

                HStack(alignment: .center, spacing: 10) {
                    Button(
                        text(
                            "Alles kopieren (Diagnose + Protokoll)",
                            "Copy all (diagnostics + log)")
                    ) {
                        copyToClipboard(appState.diagnosticsAndDebugCombinedForClipboard())
                    }
                    .liquidGlassSecondaryButtonStyle()

                    Button(text("Diagnose kopieren", "Copy diagnostics")) {
                        copyToClipboard(compressedDiagnosticsText)
                    }
                    .liquidGlassSecondaryButtonStyle()
                    .disabled(compressedDiagnosticsText.isEmpty)

                    Button(text("Diagnose exportieren", "Export diagnostics")) {
                        appState.exportDiagnosticsReport()
                    }
                    .liquidGlassSecondaryButtonStyle()

                    if appState.debugModeEnabled {
                        Button(text("Diagnoseprotokoll exportieren", "Export diagnostic log")) {
                            appState.exportDebugLog()
                        }
                        .liquidGlassSecondaryButtonStyle()
                    }
                }
            }
        }
    }

}
