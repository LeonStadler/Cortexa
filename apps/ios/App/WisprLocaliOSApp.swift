import SwiftUI

@main
struct WisprLocaliOSApp: App {
    @StateObject private var appState = IOSAppState()

    var body: some Scene {
        WindowGroup {
            IOSHomeView()
                .environmentObject(appState)
        }
    }
}

struct IOSHomeView: View {
    @EnvironmentObject private var appState: IOSAppState
    @State private var newSnippetTrigger: String = ""
    @State private var newSnippetReplacement: String = ""

    private var isSnippetFormValid: Bool {
        let triggerNotEmpty = !newSnippetTrigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let replacementNotEmpty = !newSnippetReplacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return triggerNotEmpty && replacementNotEmpty
    }

    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Offline ASR") {
                    Picker("Language", selection: $appState.selectedLanguageCode) {
                        Text("Deutsch").tag("de")
                        Text("English").tag("en")
                        Text("Auto").tag("auto")
                    }

                    Text("Selected language: \(languageDisplayName(for: appState.selectedLanguageCode))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Host app stores snippets, transcript history, diagnostics and license state in the shared container.")
                        .font(.footnote)
                }

                Section("Snippets") {
                    HStack {
                        TextField("Trigger", text: $newSnippetTrigger)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                        TextField("Replacement", text: $newSnippetReplacement)
                            .autocapitalization(.sentences)
                            .submitLabel(.done)
                            .onSubmit(commitNewSnippet)
                    }

                    Button("Add Snippet") {
                        commitNewSnippet()
                    }
                    .disabled(!isSnippetFormValid)

                    Text("Enter both a trigger and replacement to save a snippet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if appState.snippetRules.isEmpty {
                        Text("No shared snippets configured.")
                            .font(.footnote)
                    } else {
                        ForEach(appState.snippetRules) { rule in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.trigger)
                                    Text(rule.replacement)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(rule.localeIdentifier ?? "Auto")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Delete") {
                                    appState.removeSnippet(id: rule.id)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    appState.removeSnippet(id: rule.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("Transcript History") {
                    Button("Clear History") {
                        appState.clearTranscriptHistory()
                    }

                    if let latest = appState.transcriptHistory.first {
                        Button("Create snippet from latest transcript") {
                            appState.promoteTranscriptToSnippet(latest)
                        }
                    }

                    if appState.transcriptHistory.isEmpty {
                        Text("No transcripts stored yet.")
                            .font(.footnote)
                    } else {
                        ForEach(appState.transcriptHistory) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.text)
                                    Text("\(entry.languageCode) • \(Self.historyDateFormatter.string(from: entry.createdAt))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Delete") {
                                    appState.removeTranscript(id: entry.id)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    appState.promoteTranscriptToSnippet(entry)
                                } label: {
                                    Label("Snippet", systemImage: "bookmark.fill")
                                }
                                Button(role: .destructive) {
                                    appState.removeTranscript(id: entry.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("License") {
                    SecureField("License key", text: $appState.licenseInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let storedLicenseSummary = appState.storedLicenseSummary {
                        Text("Stored key: \(storedLicenseSummary)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Activate") {
                            appState.activateLicense()
                        }
                        .disabled(appState.licenseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Deactivate") {
                            appState.deactivateLicense()
                        }
                    }

                    Text("Activating a new key replaces the currently stored one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(appState.licenseStatusText)
                        .font(.footnote)
                        .foregroundStyle(appState.licenseValid ? .green : .secondary)
                }

                Section("Diagnostics") {
                    Text(appState.lastDiagnostics)
                        .font(.footnote)
                }
            }
            .navigationTitle("WisprLocal")
        }
    }

    private func commitNewSnippet() {
        guard isSnippetFormValid else { return }
        appState.addSnippet(trigger: newSnippetTrigger, replacement: newSnippetReplacement)
        newSnippetTrigger = ""
        newSnippetReplacement = ""
    }

    private func languageDisplayName(for code: String) -> String {
        switch code {
        case "de":
            return "Deutsch"
        case "en":
            return "English"
        default:
            return "Auto"
        }
    }
}
