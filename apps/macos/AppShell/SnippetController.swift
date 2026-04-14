import AppKit
import Foundation
import SnippetCore
import UniformTypeIdentifiers

@MainActor
final class SnippetController {
    private let snippetStore: SnippetStore
    private let currentSnippetRules: () -> [SnippetRule]
    private let setSnippetRules: ([SnippetRule]) -> Void
    private let currentSelectedLanguageLocaleIdentifier: () -> String
    private let appendDiagnostic: (String) -> Void
    private let appendAudit: (String) -> Void

    init(
        snippetStore: SnippetStore,
        currentSnippetRules: @escaping () -> [SnippetRule],
        setSnippetRules: @escaping ([SnippetRule]) -> Void,
        currentSelectedLanguageLocaleIdentifier: @escaping () -> String,
        appendDiagnostic: @escaping (String) -> Void,
        appendAudit: @escaping (String) -> Void
    ) {
        self.snippetStore = snippetStore
        self.currentSnippetRules = currentSnippetRules
        self.setSnippetRules = setSnippetRules
        self.currentSelectedLanguageLocaleIdentifier = currentSelectedLanguageLocaleIdentifier
        self.appendDiagnostic = appendDiagnostic
        self.appendAudit = appendAudit
    }

    func addSnippet(trigger: String, replacement: String) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTrigger.isEmpty, !trimmedReplacement.isEmpty else {
            appendDiagnostic(
                "Snippet wurde nicht gespeichert: Trigger/Replacement darf nicht leer sein.")
            return
        }

        if currentSnippetRules().contains(where: { rule in
            rule.caseSensitive
                ? rule.trigger == trimmedTrigger
                : rule.trigger.lowercased() == trimmedTrigger.lowercased()
        }) {
            appendDiagnostic("Snippet wurde nicht gespeichert: Trigger existiert bereits.")
            return
        }

        var rules = currentSnippetRules()
        rules.append(
            SnippetRule(
                trigger: trimmedTrigger,
                replacement: trimmedReplacement,
                caseSensitive: false,
                localeIdentifier: currentSelectedLanguageLocaleIdentifier()
            )
        )
        setSnippetRules(rules)
        persistSnippets()
    }

    func removeSnippet(ruleID: UUID) {
        setSnippetRules(currentSnippetRules().filter { $0.id != ruleID })
        persistSnippets()
    }

    func importSnippetsFromJSON() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        Self.configureImportSnippetsPanel(panel)

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            setSnippetRules(try snippetStore.importRules(from: url))
            appendDiagnostic("Snippets importiert: \(currentSnippetRules().count)")
            appendAudit("snippets.import path=\(url.path)")
        } catch {
            appendDiagnostic("Snippet-Import fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func exportSnippetsToJSON() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "wispr-snippets.json"
        Self.configureSavePanel(panel, titleKey: "filepanel.export.snippets.title")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try snippetStore.exportRules(currentSnippetRules(), to: url)
            appendDiagnostic("Snippets exportiert: \(currentSnippetRules().count)")
            appendAudit("snippets.export path=\(url.path)")
        } catch {
            appendDiagnostic("Snippet-Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func loadSnippets() {
        do {
            let rules = try snippetStore.load()
            setSnippetRules(rules)
            if rules.isEmpty {
                appendDiagnostic("Keine Snippets gespeichert.")
            } else {
                appendDiagnostic("Snippets geladen: \(rules.count)")
            }
        } catch {
            appendDiagnostic("Snippet-Load fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func persistSnippets() {
        do {
            try snippetStore.save(currentSnippetRules())
            appendDiagnostic("Snippets gespeichert: \(currentSnippetRules().count)")
            appendAudit("snippets.save count=\(currentSnippetRules().count)")
        } catch {
            appendDiagnostic("Snippet-Save fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private static func localizedFilePanelString(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    private static func configureImportSnippetsPanel(_ panel: NSOpenPanel) {
        panel.title = localizedFilePanelString("filepanel.import.snippets.title")
        panel.prompt = localizedFilePanelString("filepanel.open.prompt")
    }

    private static func configureSavePanel(_ panel: NSSavePanel, titleKey: String) {
        panel.title = localizedFilePanelString(titleKey)
        panel.prompt = localizedFilePanelString("filepanel.save.prompt")
    }
}
