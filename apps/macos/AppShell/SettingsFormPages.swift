import SwiftUI

struct GeneralSettingsPage: View {
    let appSectionTitle: String
    let menuBarSectionTitle: String
    let accessSectionTitle: String
    let appContent: AnyView
    let menuBarContent: AnyView
    let accessContent: AnyView

    var body: some View {
        SettingsFormPage(
            sections: [
                SettingsPageSection(id: "app", title: appSectionTitle, content: appContent),
                SettingsPageSection(
                    id: "menu-bar",
                    title: menuBarSectionTitle,
                    content: menuBarContent
                ),
                SettingsPageSection(id: "access", title: accessSectionTitle, content: accessContent),
            ]
        )
    }
}

struct SpeechSettingsPage: View {
    let quickExplainerSectionTitle: String
    let providersSectionTitle: String
    let modelSectionTitle: String
    let languageSectionTitle: String
    let qualitySectionTitle: String
    let translationSectionTitle: String
    let installedModelsSectionTitle: String
    let overviewContent: AnyView
    let providerContent: AnyView
    let modelSelectionContent: AnyView
    let languageContent: AnyView
    let qualityContent: AnyView
    let translationContent: AnyView
    let installedModelsContent: AnyView

    var body: some View {
        SettingsFormPage(
            sections: [
                SettingsPageSection(
                    id: "quick-explainer",
                    title: quickExplainerSectionTitle,
                    content: overviewContent
                ),
                SettingsPageSection(
                    id: "providers",
                    title: providersSectionTitle,
                    content: providerContent
                ),
                SettingsPageSection(
                    id: "model",
                    title: modelSectionTitle,
                    content: modelSelectionContent
                ),
                SettingsPageSection(
                    id: "language",
                    title: languageSectionTitle,
                    content: languageContent
                ),
                SettingsPageSection(
                    id: "quality",
                    title: qualitySectionTitle,
                    content: qualityContent
                ),
                SettingsPageSection(
                    id: "translation",
                    title: translationSectionTitle,
                    content: translationContent
                ),
                SettingsPageSection(
                    id: "installed-models",
                    title: installedModelsSectionTitle,
                    content: installedModelsContent
                ),
            ]
        )
    }
}

struct DictationSettingsPage: View {
    let liveRewritingSectionTitle: String
    let textInputSectionTitle: String
    let liveRewriteContent: AnyView
    let deliveryContent: AnyView

    var body: some View {
        SettingsFormPage(
            sections: [
                SettingsPageSection(
                    id: "live-rewrite",
                    title: liveRewritingSectionTitle,
                    content: liveRewriteContent
                ),
                SettingsPageSection(
                    id: "text-input",
                    title: textInputSectionTitle,
                    content: deliveryContent
                ),
            ]
        )
    }
}

struct SoundSettingsPage: View {
    let inputSectionTitle: String
    let feedbackSectionTitle: String
    let inputContent: AnyView
    let feedbackContent: AnyView

    var body: some View {
        SettingsFormPage(
            sections: [
                SettingsPageSection(id: "input", title: inputSectionTitle, content: inputContent),
                SettingsPageSection(
                    id: "feedback",
                    title: feedbackSectionTitle,
                    content: feedbackContent
                ),
            ]
        )
    }
}

struct ShortcutsSettingsPage: View {
    let startStopSectionTitle: String
    let holdSectionTitle: String
    let cancelSectionTitle: String
    let modeSwitchSectionTitle: String
    let startStopContent: AnyView
    let holdContent: AnyView
    let cancelContent: AnyView
    let modeSwitchContent: AnyView

    var body: some View {
        SettingsFormPage(
            sections: [
                SettingsPageSection(
                    id: "start-stop",
                    title: startStopSectionTitle,
                    content: startStopContent
                ),
                SettingsPageSection(id: "hold", title: holdSectionTitle, content: holdContent),
                SettingsPageSection(id: "cancel", title: cancelSectionTitle, content: cancelContent),
                SettingsPageSection(
                    id: "mode-switch",
                    title: modeSwitchSectionTitle,
                    content: modeSwitchContent
                ),
            ]
        )
    }
}

struct AISettingsPage: View {
    let processingSectionTitle: String
    let providersSectionTitle: String
    let modelsSectionTitle: String
    let processingContent: AnyView
    let providerContent: AnyView
    let modelContent: AnyView

    var body: some View {
        SettingsFormPage(
            sections: [
                SettingsPageSection(
                    id: "processing",
                    title: processingSectionTitle,
                    content: processingContent
                ),
                SettingsPageSection(
                    id: "providers",
                    title: providersSectionTitle,
                    content: providerContent
                ),
                SettingsPageSection(
                    id: "models",
                    title: modelsSectionTitle,
                    content: modelContent
                ),
            ]
        )
    }
}

struct HistorySettingsPage: View {
    let actionsSectionTitle: String
    let retentionSectionTitle: String
    let entriesSectionTitle: String
    let actionsContent: AnyView
    let retentionContent: AnyView
    let entriesContent: AnyView

    var body: some View {
        SettingsFormPage(
            sections: [
                SettingsPageSection(
                    id: "actions",
                    title: actionsSectionTitle,
                    content: actionsContent
                ),
                SettingsPageSection(
                    id: "retention",
                    title: retentionSectionTitle,
                    content: retentionContent
                ),
                SettingsPageSection(
                    id: "entries",
                    title: entriesSectionTitle,
                    content: entriesContent
                ),
            ]
        )
    }
}

struct AboutSettingsPage: View {
    let aboutMeSectionTitle: String
    let changelogSectionTitle: String
    let supportSectionTitle: String
    let developerContent: AnyView
    let changelogContent: AnyView
    let supportContent: AnyView?

    private var sections: [SettingsPageSection] {
        var sections = [
            SettingsPageSection(
                id: "developer",
                title: aboutMeSectionTitle,
                content: developerContent
            ),
            SettingsPageSection(
                id: "changelog",
                title: changelogSectionTitle,
                content: changelogContent
            ),
        ]
        if let supportContent {
            sections.append(
                SettingsPageSection(id: "support", title: supportSectionTitle, content: supportContent)
            )
        }
        return sections
    }

    var body: some View {
        SettingsFormPage(sections: sections)
    }
}

struct SnippetsSettingsPage: View {
    let newSnippetSectionTitle: String
    let importExportSectionTitle: String
    let savedSnippetsSectionTitle: String
    let newSnippetContent: AnyView
    let importExportContent: AnyView
    let savedContent: AnyView

    var body: some View {
        SettingsFormPage(
            sections: [
                SettingsPageSection(
                    id: "new-snippet",
                    title: newSnippetSectionTitle,
                    content: newSnippetContent
                ),
                SettingsPageSection(
                    id: "import-export",
                    title: importExportSectionTitle,
                    content: importExportContent
                ),
                SettingsPageSection(
                    id: "saved-snippets",
                    title: savedSnippetsSectionTitle,
                    content: savedContent
                ),
            ]
        )
    }
}

struct AdvancedSettingsPage: View {
    let appSectionTitle: String
    let modelRuntimeSectionTitle: String
    let storageLocationSectionTitle: String
    let updatesSectionTitle: String
    let diagnosticsSectionTitle: String
    let licenseSectionTitle: String
    let overviewContent: AnyView
    let appInfoContent: AnyView
    let runtimeContent: AnyView
    let storageContent: AnyView
    let updatesContent: AnyView
    let diagnosticsContent: AnyView
    let licenseContent: AnyView?

    private var sections: [SettingsPageSection] {
        var sections = [
            SettingsPageSection(id: "overview", title: nil, content: overviewContent),
            SettingsPageSection(id: "app", title: appSectionTitle, content: appInfoContent),
            SettingsPageSection(
                id: "runtime",
                title: modelRuntimeSectionTitle,
                content: runtimeContent
            ),
            SettingsPageSection(
                id: "storage",
                title: storageLocationSectionTitle,
                content: storageContent
            ),
            SettingsPageSection(id: "updates", title: updatesSectionTitle, content: updatesContent),
            SettingsPageSection(
                id: "diagnostics",
                title: diagnosticsSectionTitle,
                content: diagnosticsContent
            ),
        ]
        if let licenseContent {
            sections.append(
                SettingsPageSection(id: "license", title: licenseSectionTitle, content: licenseContent)
            )
        }
        return sections
    }

    var body: some View {
        SettingsFormPage(sections: sections)
    }
}
