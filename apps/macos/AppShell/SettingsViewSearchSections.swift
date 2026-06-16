import SwiftUI

extension SettingsView {
    private var searchResultsSections: [SettingsPageSection] {
        var sections: [SettingsPageSection] = []

        if generalHasMatches {
            sections.append(
                pageSection(id: "general", title: text("Allgemein", "General")) {
                    generalAppearanceContent
                    generalMenuBarContent
                    generalPermissionsContent
                }
            )
        }

        if dictationHasMatches {
            sections.append(
                pageSection(id: "dictation", title: text("Diktat", "Dictation")) {
                    liveRewriteContent
                    dictationDeliveryContent
                }
            )
        }

        if speechHasMatches {
            sections.append(
                pageSection(id: "speech", title: text("Speech", "Speech")) {
                    speechOverviewContent
                    speechProviderContent
                    speechModelSelectionContent
                    speechLanguageContent
                    speechQualityContent
                    translationContent
                    installedSpeechModelsContent
                }
            )
        }

        if soundHasMatches {
            sections.append(
                pageSection(id: "sound", title: text("Sound", "Sound")) {
                    soundInputContent
                    soundFeedbackContent
                }
            )
        }

        if shortcutsHasMatches {
            sections.append(
                pageSection(id: "shortcuts", title: text("Kurzbefehle", "Shortcuts")) {
                    startStopShortcutContent
                    holdShortcutContent
                    cancelShortcutContent
                    modeSwitchShortcutContent
                }
            )
        }

        if aiHasMatches {
            sections.append(
                pageSection(id: "ai", title: text("AI", "AI")) {
                    aiProcessingContent
                    aiProviderContent
                    aiModelContent
                }
            )
        }

        if historyHasMatches {
            sections.append(
                pageSection(id: "history", title: text("Verlauf", "History")) {
                    historyActionContent
                    historyRetentionContent
                    historyEntriesContent
                }
            )
        }

        if aboutHasMatches {
            sections.append(
                pageSection(id: "about", title: text("About", "About")) {
                    aboutDeveloperRows
                    aboutChangelogContent
                    aboutSupportContent
                }
            )
        }

        if snippetsHasMatches {
            sections.append(
                pageSection(id: "snippets", title: text("Snippets", "Snippets")) {
                    snippetNewEntryRows
                    snippetImportExportRows
                    snippetSavedRows
                }
            )
        }

        if dictionaryHasMatches {
            sections.append(
                pageSection(id: "dictionary", title: text("Dictionary", "Dictionary")) {
                    dictionaryNewEntryRows
                    dictionaryReviewQueueRows
                    dictionarySavedRows
                }
            )
        }

        if advancedHasMatches {
            sections.append(
                pageSection(id: "advanced", title: text("Erweitert", "Advanced")) {
                    if aboutAppMetadataMatchesSearch {
                        aboutAppInfoRows
                    }
                    advancedOverviewContent
                    voiceModelRuntimeContent
                    updatesContent
                    diagnosticsContent
                }
            )
        }

        if sections.isEmpty {
            sections.append(
                pageSection(id: "empty") {
                    Text(
                        text(
                            "Keine passenden Einstellungen gefunden.",
                            "No matching settings found."
                        )
                    )
                    .foregroundStyle(.secondary)
                }
            )
        }

        return sections
    }

    var searchResultsForm: some View {
        SearchResultsSettingsPage(sections: searchResultsSections)
    }

    private func pageSection<Content: View>(
        id: String,
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> SettingsPageSection {
        SettingsPageSection(id: id, title: title, content: erasedView(content))
    }

    func erasedView<Content: View>(@ViewBuilder _ content: () -> Content) -> AnyView {
        AnyView(content())
    }
}
