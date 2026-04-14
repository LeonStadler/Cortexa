import SwiftUI

extension SettingsView {
    @ViewBuilder
    var startStopShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat"]) {
            Toggle(
                text("Start/Stopp-Kurzbefehl aktiv", "Enable start/stop shortcut"),
                isOn: $appState.toggleShortcutEnabled)

            LabeledContent(text("Kurzbefehl", "Shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.selectedHotkey,
                    label: text("Diktier-Kurzbefehl", "Dictation shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let advisory = appState.hotkeyAdvisory {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    var holdShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "hold", "dictation", "diktat"]) {
            Toggle(
                text("Halten-zum-Diktieren aktiv", "Enable hold-to-dictate"),
                isOn: $appState.holdToDictateEnabled)

            LabeledContent {
                HotkeyRecorderField(
                    hotkey: $appState.holdShortcut,
                    label: text("Halten-zum-Diktieren-Kurzbefehl", "Hold-to-dictate shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                SettingsFieldLabel(
                    title: text("Hold-Kurzbefehl", "Hold shortcut"),
                    helpText: text(
                        "Fn allein wird im aktuellen globalen Hotkey-Pfad nicht zuverlässig unterstützt.",
                        "Fn by itself is not supported reliably in the current global hotkey path."
                    )
                )
            }
            .disabled(!appState.holdToDictateEnabled)

            if appState.holdToDictateEnabled, let advisory = appState.holdShortcutAdvisory {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    var cancelShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "cancel", "abbrechen", "diktat"]) {
            Toggle(
                text("Abbrechen-Shortcut aktiv", "Enable cancel shortcut"),
                isOn: $appState.cancelShortcutEnabled)

            LabeledContent(text("Abbrechen-Kurzbefehl", "Cancel shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.cancelShortcut,
                    label: text("Abbrechen-Kurzbefehl", "Cancel shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .disabled(!appState.cancelShortcutEnabled)

            if appState.cancelShortcutEnabled, let advisory = appState.cancelShortcutAdvisory {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    var modeSwitchShortcutContent: some View {
        if matches(["shortcut", "kurzbefehl", "mode", "modus", "diktat"]) {
            Toggle(
                text("Moduswechsel-Shortcut aktiv", "Enable mode switch shortcut"),
                isOn: $appState.modeSwitchShortcutEnabled)

            LabeledContent(text("Moduswechsel-Kurzbefehl", "Mode switch shortcut")) {
                HotkeyRecorderField(
                    hotkey: $appState.modeSwitchShortcut,
                    label: text("Moduswechsel-Kurzbefehl", "Mode switch shortcut"),
                    language: effectiveLanguage
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .disabled(!appState.modeSwitchShortcutEnabled)

            if appState.modeSwitchShortcutEnabled,
                let advisory = appState.modeSwitchShortcutAdvisory
            {
                HotkeyAdvisoryBox(advisory: advisory)
            }
        }
    }

    @ViewBuilder
    var historyActionContent: some View {
        if historyHasMatches {
            HStack(alignment: .center, spacing: 10) {
                Button(text("Letztes Diktat kopieren", "Copy last dictation")) {
                    copyToClipboard(appState.latestDictationText)
                }
                .liquidGlassPrimaryButtonStyle()
                .disabled(appState.latestDictationText.isEmpty)

                Button(text("Verlauf exportieren", "Export history")) {
                    appState.exportHistoryAsText()
                }
                .liquidGlassSecondaryButtonStyle()

                Button(role: .destructive) {
                    appState.clearHistory()
                } label: {
                    Text(text("Verlauf leeren", "Clear history"))
                }
                .liquidGlassDestructiveButtonStyle()
            }
        }
    }

    @ViewBuilder
    var historyRetentionContent: some View {
        if historyHasMatches {
            LabeledContent {
                Picker(
                    text("Verlauf aufbewahren", "Keep history"),
                    selection: $appState.historyRetentionPolicy
                ) {
                    ForEach(HistoryRetentionPolicy.allCases) { policy in
                        Text(
                            policy.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode)
                        ).tag(policy)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 180)
            } label: {
                SettingsFieldLabel(
                    title: text("Verlauf aufbewahren", "Keep history"),
                    helpText: text(
                        "Bereinigt nur den lokalen Transkriptverlauf. Systemdateien oder Roh-Audio werden dabei nicht verändert.",
                        "Prunes only the local transcript history. System files or raw audio are not changed."
                    )
                )
            }
        }
    }

    @ViewBuilder
    var historyEntriesContent: some View {
        if filteredHistory.isEmpty {
            Text(text("Keine Transkripte gefunden.", "No transcripts found."))
                .foregroundStyle(.secondary)
        } else {
            Table(compactHistoryEntries) {
                TableColumn(text("Datum", "Date")) { entry in
                    Text(formattedHistoryDate(entry.createdAt))
                        .textSelection(.enabled)
                }
                .width(min: 118, ideal: 140)
                TableColumn(text("Modus", "Mode")) { entry in
                    Text("[\(entry.mode) • \(entry.languageCode)]")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .width(min: 100, ideal: 120)
                TableColumn(text("Vorschau", "Preview")) { entry in
                    Text(entry.text)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                }
                TableColumn("") { entry in
                    HStack(spacing: 6) {
                        Button {
                            appState.copyHistoryEntry(entry)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            text("Diktat kopieren", "Copy dictation")
                        )
                        Button(role: .destructive) {
                            appState.removeHistoryEntry(entry.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            text("Diktat löschen: ", "Delete dictation: ")
                                + formattedHistoryDate(entry.createdAt))
                    }
                }
                .width(ideal: 72)
            }
            .frame(minHeight: 200)

            if !isSearching, filteredHistory.count > compactHistoryEntries.count {
                Text(
                    text(
                        "Es werden zuerst die letzten \(compactHistoryEntries.count) Diktate angezeigt. Über die Suche findest du ältere Einträge.",
                        "The latest \(compactHistoryEntries.count) dictations are shown first. Use search to find older entries."
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    var snippetNewEntryRows: some View {
        if matches(["snippet", "textbaustein", "replacement", "trigger"]) {
            LabeledContent(text("Trigger", "Trigger")) {
                TextField(text("Trigger", "Trigger"), text: $newSnippetTrigger)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 200)
                    .accessibilityLabel(text("Snippet-Trigger", "Snippet trigger"))
                    .onSubmit { commitNewSnippet() }
            }
            LabeledContent(text("Ersetzung", "Replacement")) {
                TextField(
                    text("Ersetzung", "Replacement"),
                    text: $newSnippetReplacement,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(3, reservesSpace: true)
                .accessibilityLabel(text("Snippet-Ersetzung", "Snippet replacement"))
                .onSubmit { commitNewSnippet() }
            }
            if newSnippetTriggerIsDuplicate, !trimmedNewSnippetTrigger.isEmpty {
                Text(
                    text("Dieser Trigger ist bereits vergeben.", "This trigger is already in use.")
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Button(text("Hinzufügen", "Add")) {
                commitNewSnippet()
            }
            .liquidGlassPrimaryButtonStyle()
            .disabled(!canCommitNewSnippet)
            .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder
    var snippetImportExportRows: some View {
        if matches([
            "snippet", "textbaustein", "replacement", "trigger", "json", "import", "export",
            "importieren", "exportieren",
        ]) {
            HStack(alignment: .center, spacing: 10) {
                Button(text("JSON importieren", "Import JSON")) {
                    appState.importSnippetsFromJSON()
                }
                .liquidGlassSecondaryButtonStyle()
                Button(text("JSON exportieren", "Export JSON")) {
                    appState.exportSnippetsToJSON()
                }
                .liquidGlassSecondaryButtonStyle()
            }
        }
    }

    @ViewBuilder
    var snippetSavedRows: some View {
        if matches(["snippet", "textbaustein", "replacement", "trigger"])
            || !filteredSnippets.isEmpty
        {
            if filteredSnippets.isEmpty {
                Text(text("Keine Snippets gespeichert.", "No snippets saved."))
                    .foregroundStyle(.secondary)
            } else {
                Table(filteredSnippets) {
                    TableColumn(text("Trigger", "Trigger")) { rule in
                        Text(rule.trigger)
                            .textSelection(.enabled)
                    }
                    TableColumn(text("Ersetzung", "Replacement")) { rule in
                        Text(rule.replacement)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    TableColumn("") { rule in
                        Button(role: .destructive) {
                            appState.removeSnippet(ruleID: rule.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            text("Snippet löschen: ", "Delete snippet: ") + rule.trigger)
                    }
                    .width(ideal: 44)
                }
                .frame(minHeight: 200)
            }
        }
    }

    @ViewBuilder
    var dictionaryNewEntryRows: some View {
        if matches(["dictionary", "wörterbuch", "woerterbuch", "term", "jargon", "namen"]) {
            Toggle(isOn: $appState.dictionaryAutoAddEnabled) {
                SettingsFieldLabel(
                    title: text(
                        "Vorschläge automatisch sammeln",
                        "Collect suggestions automatically"
                    ),
                    helpText: text(
                        "Auffällige Namen und Fachbegriffe werden nach dem finalen Diktat in eine Review-Liste gelegt, statt direkt übernommen zu werden.",
                        "Notable names and jargon are queued for review after final dictation instead of being added blindly."
                    )
                )
            }

            LabeledContent(text("Begriff", "Term")) {
                TextField(text("Begriff", "Term"), text: $newDictionaryTerm)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 220)
                    .onSubmit { commitNewDictionaryTerm() }
            }

            LabeledContent(text("Kategorie", "Category")) {
                Picker(text("Kategorie", "Category"), selection: $newDictionaryCategory) {
                    ForEach(DictionaryTermCategory.allCases) { category in
                        Text(
                            category.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode
                            )
                        )
                        .tag(category)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .settingsFormMenuPickerSlot(minWidth: 220)
            }

            LabeledContent(text("Sprachcode", "Language code")) {
                TextField(text("Optional", "Optional"), text: $newDictionaryLanguageCode)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 120)
            }

            HStack(spacing: 10) {
                Button(text("Hinzufügen", "Add")) {
                    commitNewDictionaryTerm()
                }
                .liquidGlassPrimaryButtonStyle()
                .disabled(!canCommitNewDictionaryTerm)

                Button(text("JSON importieren", "Import JSON")) {
                    appState.importDictionaryFromJSON()
                }
                .liquidGlassSecondaryButtonStyle()

                Button(text("JSON exportieren", "Export JSON")) {
                    appState.exportDictionaryToJSON()
                }
                .liquidGlassSecondaryButtonStyle()
            }
        }
    }

    @ViewBuilder
    var dictionaryReviewQueueRows: some View {
        if matches(["dictionary", "review", "queue", "vorschlag", "suggestion"])
            || !filteredDictionaryReviewQueue.isEmpty
        {
            if filteredDictionaryReviewQueue.isEmpty {
                Text(text("Keine offenen Vorschläge.", "No pending suggestions."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredDictionaryReviewQueue) { candidate in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.proposedTerm)
                            Text(
                                candidate.category.localizedDisplayName(
                                    interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode
                                )
                                    + (candidate.languageCode.map { " • \($0)" } ?? "")
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(text("Übernehmen", "Approve")) {
                            appState.approveDictionaryCandidate(candidate.id)
                        }
                        .liquidGlassPrimaryButtonStyle()
                        Button(role: .destructive) {
                            appState.rejectDictionaryCandidate(candidate.id)
                        } label: {
                            Text(text("Ablehnen", "Reject"))
                        }
                        .liquidGlassDestructiveButtonStyle()
                    }
                }
            }
        }
    }

    @ViewBuilder
    var dictionarySavedRows: some View {
        if matches(["dictionary", "wörterbuch", "woerterbuch", "term", "begriffe"])
            || !filteredDictionaryTerms.isEmpty
        {
            if filteredDictionaryTerms.isEmpty {
                Text(text("Keine Dictionary-Begriffe gespeichert.", "No dictionary terms saved."))
                    .foregroundStyle(.secondary)
            } else {
                Table(filteredDictionaryTerms) {
                    TableColumn(text("Begriff", "Term")) { term in
                        Text(term.term).textSelection(.enabled)
                    }
                    TableColumn(text("Kategorie", "Category")) { term in
                        Text(
                            term.category.localizedDisplayName(
                                interfaceLanguageCode: effectiveLanguage.embeddedInterfaceCode
                            )
                        )
                        .foregroundStyle(.secondary)
                    }
                    TableColumn(text("Quelle", "Source")) { term in
                        Text(term.source == .manual ? text("Manuell", "Manual") : text("Auto", "Auto"))
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("") { term in
                        Button(role: .destructive) {
                            appState.removeDictionaryTerm(termID: term.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(text("Begriff löschen", "Delete term"))
                    }
                    .width(ideal: 44)
                }
                .frame(minHeight: 200)
            }
        }
    }

}
