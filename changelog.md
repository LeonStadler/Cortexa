Warning: truncated output (original token count: 31563)
Total output lines: 765

# Changelog

## Fixes

- 2026-09-29: Vollständige Entfernung abgebrochener Cortexa-NeMo-Runtime-Installationen bei der Deinstallation.
  - Dateien: `apps/macos/AppShell/AppUninstaller.swift`, `Tests/AppShellSupportTests/AppUninstallerTests.swift`, `apps/macos/README.md`, `docs/system-design.md`, `VERSION`, `changelog.md`.
  - Funktionalität: Die Deinstallation entfernt jetzt neben bestätigten Runtime-Versionen auch versteckte Cortexa-Staging- und Backup-Ordner, wenn Versionsmuster und UUID exakt zur Installationsroutine passen. Nicht passende Ordner sowie externe Runtimes und unbekannte Modellcache-Dateien bleiben erhalten. Patch-Version `0.48.2`.

- 2026-09-29: Deinstallationsfehler beim Zurücksetzen der Datenschutzfreigaben liefern jetzt aussagekräftige Diagnoseinformationen.
  - Dateien: `apps/macos/AppShell/AppUninstaller.swift`, `Tests/AppShellSupportTests/AppUninstallerTests.swift`, `VERSION`, `changelog.md`.
  - Funktionalität: Der Deinstallationshelfer erfasst Standardausgabe und Fehlerausgabe von `tccutil`, nennt bei Fehlschlägen den Exit-Code und zeigt eine verständliche Meldung, wenn keine Diagnoseausgabe zurückkommt. Die Fehlermeldung weist jetzt darauf hin, dass App-Daten vor einem später fehlgeschlagenen Schritt bereits gelöscht worden sein können. Patch-Version `0.48.1`.

- 2026-09-28: macOS-DMG enthält wieder das Cortexa-App-Icon und die Apple-On-Device-Integration.
  - Dateien: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `scripts/validate_macos_app_runtime.sh`, `scripts/verify_macos_release_sdk.sh`, `scripts/preflight_macos_release.sh`, `apps/macos/README.md`, `docs/macos-release-checklist.md`, `docs/distribution.md`, `AGENTS.md`, `VERSION`, `changelog.md`.
  - Funktionalität: CI und Release bauen jetzt mit dem macOS-26-Runner und Xcode 26+, das die Icon-Composer-Datei zu `Cortexa.icns` kompiliert und `FoundationModels.framework` verlinkt. Ein SDK-Preflight und die Bundle-Validierung brechen den Build ab, wenn Framework oder Icon fehlen. Patch-Version `0.47.2`.

## Features

- 2026-09-29: Vollständige Deinstallation über die erweiterten Einstellungen ergänzt.
  - Dateien: `apps/macos/AppShell/AppUninstaller.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `apps/macos/AppShell/SettingsFormPages.swift`, `apps/macos/AppShell/SettingsSearchPresentation.swift`, `Tests/AppShellSupportTests/AppUninstallerTests.swift`, `Tests/AppShellSupportTests/SettingsSearchPresentationTests.swift`, `apps/macos/README.md`, `docs/system-design.md`, `VERSION`, `changelog.md`.
  - Funktionalität: Die bestätigte Aktion beendet Cortexa, entfernt App-Daten, Cache, bekannte lokale Modelle, validierte Cortexa-Runtimes, Einstellungen und Remote-AI-Schlüssel, setzt Mikrofon- und Bedienungshilfenfreigaben zurück und verschiebt das App-Bundle zuletzt in den Papierkorb. Bei laufendem Diktat oder Modellvorgängen bleibt die Aktion deaktiviert; fehlgeschlagene Schritte werden gemeldet und lassen die App zur Wiederholung installiert. Externe NeMo-Runtimes und nicht zuordenbare Modellcache-Dateien bleiben erhalten. Feature-Version `0.48.0`.

- 2026-09-28: Lizenzübersicht in den macOS-Einstellungen ergänzt.
  - Dateien: `apps/macos/AppShell/SettingsTab.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsSearchPresentation.swift`, `apps/macos/AppShell/LicensesSettingsPage.swift`, `apps/macos/WisprLocalMac/project.yml`, `apps/macos/README.md`, `docs/third-party-notices.md`, `docs/licensing.md`, `docs/README.md`, `VERSION`.
  - Funktionalität: Unter „Über Cortexa“ gibt es nun „Lizenzen“. Die Seite zeigt Cortexas Apache-2.0-Lizenz zuerst und danach die Lizenztypen/Attributionen für whisper.cpp, Sparkle, NVIDIA NeMo-Speech.cpp und Parakeet TDT v3. Jeder Drittanbieter-Eintrag öffnet direkt eine auf den gebündelten Stand gepinnte Lizenzquelle; die Parakeet-Modellkarte ist zusätzlich verlinkt. Vollständige Lizenztexte und Hinweise werden mit der macOS-App gebündelt und in den Einstellungen dargestellt. Siehe auch den Eintrag zur Apache-2.0-Umstellung am 2026-09-28.

- 2026-09-28: Cortexa auf Apache License 2.0 umgestellt und Lizenzquellen präzisiert.
  - Dateien: `LICENSE`, `NOTICE`, `README.md`, `docs/licensing.md`, `docs/third-party-notices.md`, `docs/README.md`, `apps/macos/README.md`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `apps/macos/AppShell/LicensesSettingsPage.swift`, `apps/macos/WisprLocalMac/project.yml`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`.
  - Funktionalität: Das Repository und die App weisen Cortexa nun als Apache-2.0-lizenziert aus; Copyright- und Markennotizen stehen in `NOTICE`, der vollständige Lizenztext wird mit der App gebündelt. Veraltete Aussagen zum proprietären Status wurden korrigiert. Drittanbieter-Lizenzlinks und Dokumentation nennen für whisper.cpp, Sparkle und NeMo-Speech.cpp konkrete gepinnte Commits beziehungsweise Versionen. Feature-Version `0.47.0`.

- 2026-09-27: Modellverwaltung um Anbieter-, Sprach- und Detailsuche erweitert.
  - Dateien: `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `Tests/AppShellSupportTests/SpeechModelManagementMatcherTests.swift`, `apps/macos/README.md`, `VERSION`.
  - Funktionalität: Die Modellsuche kombiniert mehrere Begriffe und findet Anbieter, lokalisierte Sprachnamen und Sprachcodes, Größe, Runtime, Dateinamen sowie unterstützte Fähigkeiten. Nicht unterstützte Sprachen oder Fähigkeiten erzeugen keine Treffer. Der Sprachfilter bietet neben Sprachumfang nun konkrete Erkennungssprachen und Auto-Erkennung; Modellzeilen nennen ihren Anbieter und den tatsächlichen Sprachumfang. Feature-Version `0.45.0`.

- 2026-09-27: Modellabhängige Sprach- und Diktatoptionen mit bestätigtem Modellwechsel eingeführt.
  - Dateien: `Sources/ASRCore/VoiceModelCatalog.swift`, `apps/macos/AppShell/VoiceModelCapabilityPolicy.swift`, `apps/macos/AppShell/MacAppStateModelCapabilities.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/SessionConfigurationBuilder.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/SettingsViewAISections.swift`, `apps/macos/AppShell/Onboarding/OnboardingView.swift`, `Tests/AppShellSupportTests/VoiceModelCapabilityPolicyTests.swift`, `Tests/AppShellSupportTests/SessionConfigurationBuilderTests.swift`, `Tests/AppShellSupportTests/SpeechModelControllerTests.swift`, `apps/macos/README.md`, `docs/system-design.md`, `VERSION`.
  - Funktionalität: Die Fähigkeiten des tatsächlich verwendeten Modells einschließlich sprachspezifischer Zuordnungen steuern Sprache, Auto-Erkennung, Übersetzung, Live-Text und Qualitätsprofil in Settings und Menüleiste. Nicht unterstützte Optionen bleiben sichtbar und bieten einen bestätigten Wechsel zu einem bevorzugten oder sonst kompatiblen Modell mit Download bei Bedarf. Auswahl und Modell wechseln erst nach erfolgreicher Installation; Abbruch, Fehler oder zwischenzeitlicher manueller Modellwechsel lassen die bisherige Auswahl bestehen. Inkompatible persönliche Präferenzen bleiben gespeichert, werden während der Sitzung sicher pausiert und bei geeignetem Modell wieder wirksam. Modell-Details aktualisieren sich beim Wechsel ohne erneutes Öffnen der Ansicht. Feature-Version `0.44.0`.

- 2026-09-26: Modell-Auswahl, Download-Abbruch und Qualitätsprofil an Provider-Fähigkeiten angepasst.
  - Dateien: `Sources/ASRCore/VoiceModelDownloadClient.swift`, `Sources/ASRCore/VoiceModelInstaller.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/MacAppStateFacadeActions.swift`, `apps/macos/AppShell/Onboarding/OnboardingView.swift`, `apps/macos/AppShell/SettingsChromeComponents.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Der Modell-Picker listet Provider-unabhängig den Katalog auf. Laufende Modell- und NeMo-Runtime-Downloads lassen sich abbrechen; Netzwerkaufgabe und temporäre Daten werden bereinigt, und eine nur für den abgebrochenen Parakeet-Vorgang installierte Runtime wird entfernt. Fortschritt und Prozentwert erscheinen nur einmal. Das Qualitätsprofil ist für Parakeet deaktiviert, da die NeMo-Engine die Whisper-Presets nicht verwendet. Die redundante Offline-Erklärung wurde aus der Parakeet-Modellzeile entfernt. Feature-Version `0.43.0`.

- 2026-09-26: NeMo-Speech Runtime wird von Cortexa versioniert installiert und nach dem letzten abhängigen Modell automatisch bereinigt.
  - Dateien: `Sources/ASRCore/VoiceModelCatalog.swift`, `Sources/ASRCore/VoiceModelInstallProgress.swift`, `Sources/ASRCore/VoiceModelInstaller.swift`, `Sources/ASRCore/WhisperCppEngine.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/MacAppStateFacadeActions.swift`, `apps/macos/AppShell/SettingsChromeComponents.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `Tests/ASRCoreTests/VoiceModelCatalogTests.swift`, `Tests/ASRCoreTests/NemoSpeechRuntimeManagerTests.swift`, `Tests/ASRCoreTests/ParakeetIntegrationSmokeTests.swift`, `scripts/smoke_test_parakeet.sh`, `apps/macos/README.md`, `docs/system-design.md`, `VERSION`
  - Funktionalität: Parakeet deklariert `nemo-speech` als Runtime-Abhängigkeit. Auf Apple Silicon installiert Cortexa bei Bedarf den gepinnten NVIDIA-NeMo-Speech-0.1.0-Metal-Build nach `~/Library/Application Support/Cortexa/Runtime/NeMo-Speech/0.1.0`, prüft das offizielle Archiv per SHA-256 und bewahrt Runtime-Lizenzen und Drittanbieterhinweise. Kompatible externe Runtimes werden ausschließlich lesend genutzt. Beim Entfernen des letzten abhängigen Modells entfernt Cortexa die eigene Runtime nach Ende laufender NeMo-Aufträge; fehlgeschlagene Bereinigung ist in Settings erneut ausführbar. Ein installierter Parakeet-Eintrag bietet bei fehlender Runtime deren Einrichtung an. Der Smoke-Test installiert fehlende Assets über `VoiceModelInstaller` und führt die Transkription über `ASRCore` real aus. Feature-Version `0.42.0`.

- 2026-09-26: Modellverwaltung zeigt Modelle aller Anbieter mit Provider-Filter; Parakeet erhält einen echten Engine-Smoke-Test.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `Sources/ASRCore/VoiceModelCatalog.swift`, `Tests/ASRCoreTests/ParakeetIntegrationSmokeTests.swift`, `scripts/smoke_test_parakeet.sh`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Die Modellverwaltung ist nicht mehr auf den aktiven Transkriptionsanbieter beschränkt. Parakeet ist so auch ohne installierte NeMo-Runtime sichtbar und kann separat heruntergeladen werden. Ein Provider-Filter wird dynamisch aus den Kataloganbietern aufgebaut; die Suche berücksichtigt zusätzlich Provider-Namen und -IDs. Ein Modell wird nach dem Download nur automatisch ausgewählt, wenn sein Backend verfügbar ist; die Standardauswahl bleibt bei fehlender Runtime deaktiviert. Der Parakeet-Smoke-Test erzeugt Sprache, lädt das Modell über die bestehende ASRCore-Engine und prüft die Transkription. Lizenzhinweise für Runtime und Modell sind dokumentiert. Feature-Version `0.41.0`.

- 2026-09-26: NVIDIA Parakeet TDT v3 als optionales lokales Offline-ASR-Modell angebunden.
  - Dateien: `Sources/ASRCore/VoiceModelCatalog.swift`, `Sources/ASRCore/VoiceModelInstaller.swift`, `Sources/ASRCore/ASRTypes.swift`, `Sources/ASRCore/WhisperCppEngine.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `Tests/ASRCoreTests/VoiceModelCatalogTests.swift`, `apps/macos/README.md`, `docs/system-design.md`, `VERSION`
  - Funktionalität: Parakeet TDT v3 ist im lokalen Modellkatalog und lädt sein offizielles Q8-GGUF direkt von NVIDIA Hugging Face in den NeMo-Speech-Cache. Für die Transkription wird zusätzlich NVIDIA NeMo-Speech.cpp benötigt. Die Aufnahme wird nach dem Stoppen verarbeitet; automatische Erkennung deckt 25 europäische Sprachen ab, Live-Teiltranskripte und Übersetzung sind nicht verfügbar. Feature-Version `0.40.0`.

- 2026-09-26: Sitzungsauflösung und Live-Einfügen an Parakeets Offline-Modus angepasst; finale Einfügung wartet auf ausstehende Live-Updates.
  - Dateien: `apps/macos/AppShell/SessionConfigurationBuilder.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/SettingsViewAISections.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/Onboarding/OnboardingView.swift`, `Tests/AppShellSupportTests/SessionConfigurationBuilderTests.swift`
  - Funktionalität: Parakeet wird als installiertes Modell im tatsächlichen Sitzungsvertrag erkannt und erzwingt den Finalize-Modus. Live-Text- und Live-AI-Schalter werden bei Parakeet deaktiviert. Der finale Text wird erst ausgeliefert, nachdem bereits eingereihte Live-Einfügungen abgearbeitet sind.

- 2026-09-14: Native macOS-Settings-Navigation, datensparsame Suche und systemnahe Hilfen überarbeitet.
  - Dateien: `apps/macos/AppShell/SettingsTab.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/SettingsSearchPresentation.swift`, `apps/macos/AppShell/SearchResultsSettingsPage.swift`, `apps/macos/AppShell/SettingsChromeComponents.swift`, `apps/macos/AppShell/SettingsViewAIProviderSections.swift`, `apps/macos/AppShell/SettingsWindowPresenter.swift`, `Tests/AppShellSupportTests/SettingsTabTests.swift`, `Tests/AppShellSupportTests/SettingsSearchPresentationTests.swift`, `apps/macos/README.md`, `docs/features-and-implementation.md`, `VERSION`
  - Funktionalität: Settings sind nun in lokalisierte Sidebar-Gruppen aufgeteilt, merken sich den zuletzt verwendeten Bereich und öffnen Suchtreffer als gezielte Bereichsnavigation statt vollständige Formulare zusammenzumontieren. Die Suche liest keine persönlichen Diktat-, Wörterbuch- oder Textbaustein-Inhalte mehr. Eigene Hover-Popovers wurden durch native macOS-Hilfe ersetzt; KI-Anbieter werden als kompakte systemnahe Auswahlliste dargestellt. Die Version wurde als Minor-Feature-Release auf `0.30.0` angehoben.

- 2026-09-02: Dynamische Modell-Synchronisierung für Remote-Anbieter ergänzt.
  - Dateien: `apps/macos/AppShell/AIProviderController.swift`, `apps/macos/AppShell/MacAppStateFacadeActions.swift`, `apps/macos/AppShell/SettingsViewAIProviderSections.swift`, `VERSION`
  - Funktionalität: Aktivierte Anbieter synchronisieren ihren Modellkatalog automatisch beim Öffnen der AI-Einstellungen. Zusätzlich kann der ausgewählte Anbieter jederzeit über „Modelle aktualisieren“ manuell synchronisiert werden. Parallel laufende Abrufe werden pro Anbieter zusammengeführt; erfolgreiche leere Antworten entfernen veraltete Modelle, Fehler bleiben sichtbar und behalten die letzte bekannte Liste. Die Version wurde als Feature-Release auf `0.29.0` angehoben.

## Chores

- 2026-09-29: Release-Notizen automatisch aus gemergten PRs und direkten Commits erstellen.
  - Dateien: `.github/release.yml`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/workflows/release.yml`, `scripts/generate_macos_release_notes.sh`, `AGENTS.md`, `docs/distribution.md`, `changelog.md`.
  - Funktionalität: Der manuelle macOS-Release-Workflow erzeugt jetzt kategorisierte GitHub-Release-Notizen einschließlich Beitragenden und Commit-Nachrichten ohne PR. Eine PR-Vorlage beschreibt verständliche Titel und erforderliche Release-Labels; die Notiz enthält außerdem kurze Installationshinweise und den maschinenlesbaren getesteten Quell-Commit. Produktversion unverändert, da nur Release-Tooling und Dokumentation geändert wurden.

- 2026-09-28: Publish-Prüfung für GitHub-Draft-Releases korrigiert.
  - Dateien: `.github/workflows/release.yml`, `AGENTS.md`, `docs/distribution.md`, `changelog.md`.
  - Funktionalität: Der Publish-Workflow erwartet keinen Git-Tag vor der Veröffentlichung, weil GitHub den Tag bei einem Draft noch nicht anlegt. Stattdessen prüft er den im Draft dokumentierten Quell-Commit gegen die aktuelle `main`-Historie, bindet beim Veröffentlichen den Tag explizit an diesen Commit und kontrolliert anschließend dessen Ziel. Bugfix-Version `0.47.1`.

- 2026-09-28: GitHub-Actions-Releasepfad für macOS-DMGs eingerichtet.
  - Dateien: `.github/workflows/release.yml`, `AGENTS.md`, `README.md`, `docs/distribution.md`, `docs/macos-release-checklist.md`, `changelog.md`, `VERSION`.
  - Funktionalität: Der manuell auf `main` gestartete Workflow baut und prüft den arm64-DMG auf einem öffentlichen GitHub-Runner und legt DMG, SHA-256 und Installationshinweise als Draft-Release an. Ein separater `publish`-Lauf prüft Version, Tag, Quell-Commit, Assets, Prüfsumme und DMG-Integrität, bevor er den Draft veröffentlicht. Das hält den Installationstest als Freigabeschritt bei. Chore-Patch `0.47.1`.

- 2026-09-28: Lokalen Open-Source-macOS-Release ohne Apple-Developer-ID eingerichtet.
  - Dateien: `scripts/build_macos_open_source_release.sh`, `scripts/create_macos_dmg.sh`, `README.md`, `docs/distribution.md`, `docs/macos-release-checklist.md`, `docs/permissions-macos.md`, `docs/licensing.md`, `docs/README.md`, `Tests/DocsContractTests/PermissionRecoveryContractTests.swift`.
  - Funktionalität: Ein einzelner lokaler Build-Befehl initialisiert Whisper bei Bedarf, baut und validiert Cortexa samt Whisper-Runtime gezielt für arm64 mit ad-hoc Signatur, erstellt einen überprüften DMG mit SHA-256 und Installationshinweisen und räumt frühere Build-Ausgaben des Checkouts auf. Die DMG-Verpackung erlaubt ad-hoc signierte Apps ausschließlich für diesen expliziten Open-Source-Pfad. Dokumentation erklärt die erstmalige macOS-Freigabe sowie mögliche erneute Berechtigungsabfragen bei Updates. Kein Produktversionsbump, da dies eine Release-Tooling-Änderung ist.

## Docs

- 2026-09-28: Release-Ablauf nach PR-Merge und direkten Änderungen auf `main` präzisiert.
  - Dateien: `AGENTS.md`, `changelog.md`.
  - Funktionalität: Dokumentiert, dass ein PR-Merge keinen automatischen Produktrelease auslöst; Release-Build und Tests müssen vom finalen `main`-Commit stammen, geänderte oder veraltete Branch-Builds werden neu erstellt, und Veröffentlichung erfolgt erst nach Installationstest und ausdrücklicher Freigabe. Der GitHub-Release-Befehl verwendet `--target main` und prüft danach die Tag-Zuordnung. Kein Produktversionsbump, da reine Prozessdokumentation.

- 2026-09-28: Versionierung, lokaler DMG-Test und GitHub-Veröffentlichung in `AGENTS.md` festgehalten.
  - Dateien: `AGENTS.md`, `changelog.md`.
  - Funktionalität: Der verbindliche Ablauf beschreibt Branch- und Commit-Vorbereitung, Versionsbump nach erfolgreichen Implementierungstests, arm64-DMG-Build, Prüfsummen-/Image-Prüfung, Nutzerfreigabe nach Installationstest und erst danach Push sowie GitHub-Release. Er dokumentiert außerdem die Gatekeeper-Hinweise, Release-Assets und Rückprüfung der heruntergeladenen GitHub-Dateien. Kein Produktversionsbump, da nur Prozessdokumentation geändert wurde.

## Fixes

- 2026-09-28: Modell-Detailsuche mit kleineren, explizit typisierten String-Ausdrücken für den macOS-15-Compiler stabilisiert.
  - Dateien: `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `changelog.md`.
  - Funktionalität: Die Modell-Suchdaten werden schrittweise aufgebaut und mit einem gemeinsamen typisierten Faltoptionen-Wert normalisiert. Das beseitigt den Compiler-Timeout im Apple-Silicon-Release-Runner, ohne Suchverhalten oder Treffer zu ändern. Bugfix-Version `0.47.1`.

- 2026-09-28: Qualitätsprofile nur für kompatible Sprachmodelle anzeigen.
  - Dateien: `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/README.md`, `VERSION`, `changelog.md`.
  - Funktionalität: Modelle ohne Qualitätsprofile zeigen in Settings nur einen Hinweis auf ihre festen Erkennungsparameter; wirkungslose Auswahl- und Modellwechsel-Aktionen entfallen auch in der Menüleiste. Die gespeicherte Whisper-Auswahl bleibt erhalten. Whisper-Profile erklären jetzt die Auswirkungen auf Suchaufwand, Laufzeit und Live-Zwischenstände. Bugfix-Version `0.45.1`.

- 2026-09-28: Release-Archive, DMG- und App-Smoke prüfen die enthaltene Whisper-Runtime; Berechtigungshinweise sind in den Settings gezielter erreichbar.
  - Dateien: `apps/macos/AppShell/PermissionCoordinator.swift`, `apps/macos/AppShell/SettingsFormPages.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `Tests/AppShellSupportTests/PermissionCoordinatorTests.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `Tests/DocsContractTests/PermissionRecoveryContractTests.swift`, `scripts/archive_macos_release.sh`, `scripts/create_macos_dmg.sh`, `scripts/smoke_test_macos_app.sh`, `scripts/validate_macos_app_runtime.sh`, `docs/distribution.md`.
  - Funktionalität: Release-Artefakte und Smoke-Läufe prüfen vorab, ob das App-Bundle eine ausführbare `whisper-cli`, Modellverzeichnis und gültige Runtime-Manifestdatei enthält. Das Manifest wird mit Python geprüft und die CLI mit `--help` gestartet. Die Accessibility-Anfrage öffnet nur noch den nativen macOS-Einstiegspunkt; offene Berechtigungen werden in den passenden Settings-Bereich geleitet.

- 2026-09-28: DMG-Prüfung verhindert Finder-Metadaten auf dem signierten App-Bundle.
  - Dateien: `scripts/create_macos_dmg.sh`, `scripts/macos_dmg_settings.py`, `Tests/DocsContractTests/DocsContractTests.swift`, `docs/distribution.md`.
  - Funktionalität: Das DMG-Layout blendet die App-Erweiterung nicht mehr mit `SetFile` aus, da dies `com.apple.FinderInfo` auf `Cortexa.app` geschrieben und die Code-Signatur ungültig gemacht hat. Nach dem Verpacken wird die Signatur des App-Bundles im DMG erneut geprüft.

- 2026-09-26: Menüleisten-Dropdown bleibt bei Speech-Modell-Downloads stabil.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/Onboarding/OnboardingView.swift`, `apps/macos/AppShell/Onboarding/OnboardingWindowPresenter.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/SettingsWindowPresenter.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `VERSION`
  - Funktionalität: Häufige Download-Fortschritte laufen über einen eigenen beobachtbaren Store statt über den globalen App-Zustand. Settings und Onboarding beobachten diesen Store direkt; das Menüleistenfenster wird während des Downloads nicht bei jedem Fortschritt neu aufgebaut. Doppelklicks auf ein bereits ladendes Modell starten keinen zweiten Installationsvorgang. Bugfix-Version `0.43.2`.

- 2026-09-26: Parakeet erscheint auch in der Modell-Auswahl der Menüleiste.
  - Dateien: `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `VERSION`
  - Funktionalität: Menüleisten- und Einstellungs-Picker verwenden den vollständigen Modellkatalog statt Modelle auf den aktiven Provider zu begrenzen. Damit können installierte Parakeet-Modelle providerübergreifend angezeigt und ausgewählt werden. Bugfix-Version `0.43.1`.

- 2026-09-26: macOS-DMG setzt keine Finder-Informationen mehr auf dem signierten App-Bundle.
  - Dateien: `scripts/macos_dmg_settings.py`
  - Funktionalität: `dmgbuild` blendet `.app`-Erweiterungen ohne manuelle Finder-Markierung aus. Das verhindert `com.apple.FinderInfo` auf `Cortexa.app` und erhält die strikte Code-Signaturprüfung nach dem Kopieren aus dem DMG.

- 2026-09-26: Modellfähigkeiten zentralisiert und NVIDIA-Modellinstallation sowie Live-Pipeline gegen inkompatible Konfigurationen abgesichert.
  - Dateien: `Sources/ASRCore/ASRTypes.swift`, `Sources/ASRCore/VoiceModelCatalog.swift`, `Sources/ASRCore/VoiceModelDownloadClient.swift`, `Sources/ASRCore/VoiceModelInstaller.swift`, `Sources/ASRCore/WhisperCppEngine.swift`, `apps/macos/AppShell/SessionConfigurationBuilder.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `Tests/ASRCoreTests/VoiceModelCatalogTests.swift`, `Tests/ASRCoreTests/WhisperCppEngineLifecycleTests.swift`, `Tests/AppShellSupportTests/SessionConfigurationBuilderTests.swift`, `Tests/AppShellSupportTests/SpeechModelControllerTests.swift`, `apps/macos/README.md`, `docs/system-design.md`, `VERSION`
  - Funktionalität: Modellbeschreibungen steuern Live-Transkription, automatische Erkennung, manuelle Sprachauswahl, Sprachcodes, Übersetzung und Aufnahmedauer. Parakeet wird auch ohne NeMo-Laufzeit im Katalog gezeigt und kann direkt von NVIDIA heruntergeladen werden; sein dokumentierter Dateiname wird einheitlich beim Installieren und Laden verwendet. NeMo-Transkription verwendet die konfigurierte Sprachvorgabe und leert stdout/stderr gleichzeitig, um Hänger bei größeren Ausgaben zu vermeiden. HTTP-Fehlerantworten werden beim Download abgewiesen; Aufnahmen, die die Modellgrenze überschreiten, brechen mit einem Fehler ab, statt ältere Sprache still zu verwerfen. Versionspatch `0.40.1`.

- 2026-09-26: Lokalen Modellfilter klar von der globalen Einstellungssuche abgegrenzt.
  - Dateien: `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `VERSION`
  - Funktionalität: Die Formularzeile heißt nun „Modellfilter“; der Platzhalter benennt die durchsuchbaren Modellfelder Name, Sprache und ID. Damit entfallen die doppelte Beschriftung innerhalb der Zeile und die Verwechslung mit der globalen Einstellungssuche. Die Version wurde als Patch-Bugfix auf `0.30.9` angehoben.

- 2026-09-26: Modellverwaltung in native macOS-Einstellungszeilen überführt.
  - Dateien: `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `VERSION`
  - Funktionalität: Suche, Status- und Sprachfilter werden als native `LabeledContent`-Formularzeilen mit systemeigenen Textfeldern und Menüs dargestellt. Jedes Modell erhält eine beschriftete Formularzeile mit Status, nativen Aktionen und Fortschritt; eigene Trennlinien und die separate Werkzeugleistenoptik entfallen. Für leere Suchergebnisse wird `ContentUnavailableView` verwendet. Die Version wurde als Patch-Bugfix auf `0.30.8` angehoben.

- 2026-09-26: Modellverwaltung auf native Such-, Filter- und Zeilenlayouts umgestellt.
  - Dateien: `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `VERSION`
  - Funktionalität: Modellsuche, Status-Scope und Sprachfilter sind als zusammengehörige Werkzeugleiste ohne formularartige Einzelzeilen angeordnet. Modellinfos, Status und Aktionen erscheinen in kompakten, durch native Separatoren getrennten Zeilen. Filterlogik und Modellaktionen bleiben unverändert. Die Version wurde als Patch-Bugfix auf `0.30.7` angehoben.

- 2026-09-26: Settings-Sidebar, Modellsuche und Berechtigungsablauf systemnäher gestaltet; DMG-Signatur abgesichert.
  - Dateien: `apps/macos/AppShell/PermissionCoordinator.swift`, `apps/macos/AppShell/SettingsTab.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `scripts/create_macos_dmg.sh`, `Tests/AppShellSupportTests/AppShellCharacterizationTests.swift`, `Tests/AppShellSupportTests/PermissionCoordinatorTests.swift`, `Tests/AppShellSupportTests/SettingsTabTests.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `Tests/DocsContractTests/PermissionRecoveryContractTests.swift`, `docs/macos-release-checklist.md`, `docs/permissions-macos.md`, `VERSION`
  - Funktionalität: Doppelte Sidebar-Bezeichnungen und die leere Info-Gruppenüberschrift entfallen. Suche, Status- und Sprachfilter nutzen die systemnahen SwiftUI-Steuerelemente ohne redundante Labels. Die Bedienungshilfen-Anfrage löst nicht länger gleichzeitig den Systemdialog und ein automatisches Öffnen der Systemeinstellungen aus. DMGs werden nur noch aus Apps mit überprüfbarer persistenter Apple-Signatur und TeamIdentifier erstellt. Die Version wurde als Patch-Bugfix auf `0.30.6` angehoben.

- 2026-09-25: Settings-Sidebar und Speech-Modellfilter an die native macOS-Darstellung angepasst.
  - Dateien: `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `VERSION`
  - Funktionalität: Die Sidebar nutzt wieder die kompakte System-Zeilendarstellung. Suche, Status und Sprache in der Modellverwaltung stehen als klar beschriftete Formularzeilen; die Statuswahl verwendet ein natives Menü, und das Suchfeld hat ein systemnahes Lupen- und Löschen-Steuerelement. Filter- und Suchlogik bleiben erhalten. Die Version wurde als Patch-Bugfix auf `0.30.5` angehoben.

- 2026-09-14: Settings-Layout bei kleinen Fensterbreiten stabilisiert.
  - Dateien: `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/MacNativeDesign.swift`, `VERSION`
  - Funktionalität: Die Sidebar erhält einen stabilen nativen Innenabstand. Die Modellverwaltung wechselt bei schmalen Detailspalten automatisch von einer einzeiligen Such-/Filterleiste auf eine kompakte zweizeilige Anordnung. Modellzeilen verwenden einen responsiven Fallback für Status und Aktionen; Settings-Buttons nutzen wieder die nativen macOS-Varianten. Die Version wurde als Patch-Bugfix auf `0.30.1` angehoben.

- 2026-09-25: DMG-Hintergrund auf Finder-Leinwand skaliert, Textdarstellung erhalten.
  - Dateien: `apps/macos/AppShell/Resources/CortexaInstallerBackground.svg`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`
  - Funktionalität: Das Hintergrundmotiv verwendet nun eine echte 800 × 500 SVG-Leinwand. Die bisherigen Textzeilen, Farben und der Pfeil werden proportional auf die Finder-Fläche transformiert und von `sips` in korrekter Größe gerendert. Die Version wurde als Patch-Bugfix auf `0.30.4` angehoben.

- 2026-09-24: DMG-Installationshintergrund wird auch unter macOS 27 zuverlässig angezeigt.
  - Dateien: `scripts/create_macos_dmg.sh`, `scripts/macos_dmg_settings.py`, `scripts/requirements-macos-dmg.txt`, `apps/macos/AppShell/Resources/CortexaInstallerBackground.svg`, `Tests/DocsContractTests/DocsContractTests.swift`, `docs/distribution.md`, `VERSION`
  - Funktionalität: Die DMG-Erstellung verwendet jetzt das gepinnte `dmgbuild` statt Finder-gesteuerter `create-dmg`-Hintergrundkonfiguration. Fenstergröße, Motiv, Icon-Positionen und Programme-Verknüpfung werden direkt in die Finder-Metadaten geschrieben. Das Ergebnis wurde auf macOS 27 im Finder visuell geprüft. Die Version wurde als Patch-Bugfix auf `0.30.3` angehoben.

- 2026-09-23: DMG-Installationshintergrund passend zum Finder-Fenster skaliert und ausgerichtet.
  - Dateien: `apps/macos/AppShell/Resources/CortexaInstallerBackground.svg`, `scripts/create_macos_dmg.sh`, `Tests/DocsContractTests/DocsContractTests.swift`, `docs/distribution.md`, `VERSION`
  - Funktionalität: Das Motiv nutzt eine 800 × 500-Leinwand passend zum Finder-Fenster. `sips` rendert die SVG direkt; `create-dmg` speichert Hintergrund, Fenstergröße, App- und Programme-Position gemeinsam in der Finder-Metadatei. Dadurch hängt die Darstellung nicht mehr von einem relativen AppleScript-Dateipfad oder einem bereits geöffneten gleichnamigen Volume ab. Die Version wu…15563 tokens truncated…rendert; danach bauen sowohl das macOS-App-Target (`WisprLocalMac`) als auch das iOS-Projekt mit Keyboard-Extension (`WisprLocaliOS`) erfolgreich per `xcodebuild`.

- 2026-03-17: ASR-/Session-Core und Text-Insertion auf Produktionsfehler und sichere Fallbacks gehärtet.
  - Dateien: `Sources/ASRCore/WhisperCLIExecutor.swift`, `Sources/ASRCore/ModelRegistry.swift`, `Sources/SessionCore/SessionStateMachine.swift`, `Sources/SessionCore/StreamingCommitStabilizer.swift`, `Sources/TextTargetMac/AXTextTargetServices.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/AppShell/MacAppState.swift`
  - Funktionalität: `whisper-cli` nutzt jetzt korrekt `--beam-size` statt des Batch-Flags, fehlerhafte Modellimporte räumen ungültige Dateien auf, Session-Operation-IDs werden zwischen Läufen sauber zurückgesetzt, Streaming-Commits binden an Wort-/Satzgrenzen statt ganze instabile Tails zu fixieren, Clipboard-Fallbacks werden bei Fokuswechsel blockiert, der globale Hotkey registriert sich nur einmal, und ein Syntaxfehler im macOS-App-State wurde bereinigt.

- 2026-03-11: Accessibility-Key-Typfehler in der macOS-App behoben.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: Korrekte Verwendung von `kAXTrustedCheckOptionPrompt.takeUnretainedValue()` verhindert Compile-Fehler in Xcode.

- 2026-03-04: Accessibility-Permission-Abfrage in macOS-App kompiliert/funktional korrigiert.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: `AXIsProcessTrustedWithOptions` nutzt jetzt den korrekten Key (`kAXTrustedCheckOptionPrompt.takeUnretainedValue()`), wodurch der Xcode-Compile-Fehler behoben ist.

- 2026-03-04: macOS-Xcode-Projektgenerierung korrigiert, damit neue AppShell-Dateien und Package-Dependencies zuverlässig im Target landen.
  - Dateien: `apps/macos/WisprLocalMac/project.yml`, `scripts/generate_macos_xcodeproj.sh`, `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj/project.pbxproj`
  - Funktionalität: `DictationRuntime.swift` und benötigte Produkte (`ASRCore`, `SnippetCore`, `SessionCore`, `CapabilityCore`) werden beim Generieren konsistent eingebunden.

- 2026-03-03: Build-Skript gegen fehlende iOS-SDK/Xcode-Umgebung robust gemacht.
  - Dateien: `scripts/build_whisper_xcframework.sh`
  - Funktionalität: XCFramework-Build wird bei fehlender voller Xcode-Umgebung nicht mehr hart abgebrochen; macOS-`whisper-cli` wird trotzdem zuverlässig gebaut.

- 2026-03-03: Platzhalter-Transkription in der ASR-Engine vollständig entfernt.
  - Dateien: `Sources/ASRCore/WhisperCppEngine.swift`
  - Funktionalität: `pushAudioPCM16kMono`, `stopStreaming` und `transcribeFile` nutzen jetzt ausschließlich echte lokale Decoding-Läufe statt Dummy-Text.

- 2026-03-03: Streaming-Partial-Handling gegen veraltete Decode-Ergebnisse stabilisiert.
  - Dateien: `Sources/ASRCore/WhisperCppEngine.swift`
  - Funktionalität: Versionsbasierte Partial-Publikation (`decodeVersion`) verhindert veraltete Partial-Updates bei konkurrierenden Decodes.

## Features

- 2026-03-25: macOS-Menü und Settings an kompaktere Preferences-/Menu-Bar-Struktur angepasst.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/AppLanguage.swift`
  - Funktionalität: Das Menüleisten-Menü zeigt jetzt einen kompakten Status-Header, fokussierte Primäraktionen, explizite Update-/Settings-Aktionen und problembezogene Berechtigungsaktionen; das Settings-Fenster nutzt eine preference-artige Fensterkonfiguration, fünf aufgeräumte Reiter (`Allgemein`, `Diktat`, `Kurzbefehle`, `Verlauf`, `Erweitert`) sowie ein überarbeitetes Suchfeld.

- 2026-03-25: Menü- und Settings-Polish für macOS weiter verfeinert.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SettingsView.swift`
  - Funktionalität: Das Menü nutzt jetzt zusätzliche Status-Pills und Kartenflächen für Quick Controls, Berechtigungen und das letzte Diktat; das Suchfeld in den Settings erhielt einen klareren visuellen Rahmen, damit es sich konsistenter in die Präferenzoberfläche einfügt.

- 2026-03-25: macOS-Diktat unterstützt jetzt Clipboard-Only und Clipboard-Fallback ohne Verlust der History.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`
  - Funktionalität: In den Einstellungen kann gewählt werden, ob finale Diktate direkt eingefügt oder nur in die Zwischenablage kopiert werden; zusätzlich kann nach einem 5-Sekunden-Timeout ohne Textziel automatisch die Zwischenablage als Fallback verwendet werden, während die History weiterhin immer gepflegt wird.

- 2026-03-25: macOS-Shortcut-Recorder und Menülabels barriereärmer und sprachkonsistenter gemacht.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/AppLanguage.swift`
  - Funktionalität: Shortcut-Aufnahme und Menüaktionen haben jetzt konsistentere deutsch/englische Labels, sichtbare Zustände für die Aufnahme eines Shortcuts und zusätzliche Accessibility-Beschriftungen/Hinweise für VoiceOver.

- 2026-03-25: macOS-Diktat um konfigurierbares Hold-to-dictate erweitert.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/AppShell/SettingsView.swift`
  - Funktionalität: Neben dem normalen Toggle-Shortcut kann jetzt ein separater Hold-to-dictate-Shortcut aktiviert, aufgezeichnet oder deaktiviert werden; Start/Stop-Shortcut und Hold-Shortcut lassen sich unabhängig ein- oder ausschalten und werden mit Konfliktwarnungen in den Settings angezeigt.

- 2026-03-25: macOS-App-Sprache jetzt konsistenter über Menü und Diktat-Settings gespiegelt.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: Die App kann weiterhin zwischen Deutsch und Englisch umgeschaltet werden; zusätzlich folgen jetzt auch die Anzeigen für Diktatsprache und Performance im Menü sowie in den Settings der gewählten UI-Sprache.

- 2026-03-25: macOS-App-UI um lokale App-Sprache und kompakte Menüleisten-Steuerung erweitert.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SettingsView.swift`
  - Funktionalität: Die UI-Bedienelemente können zwischen Deutsch und Englisch umgeschaltet werden; die Menüleistenansicht bleibt kompakt und zeigt nur die Kernaktionen mit sichtbaren Shortcut-Hinweisen.

- 2026-03-25: Diktat kann jetzt ohne sofort verfügbares Textfeld starten und später in ein fokussiertes Ziel einfügen.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: Aufnahme bricht nicht mehr ab, wenn beim Start kein Textfeld aktiv ist; Streaming hält den aktuellen Preview-Text zurück und fügt ihn ein, sobald während der Aufnahme ein Textfeld fokussiert wird, und der finale Text wartet nach dem Stop bis zu fünf Sekunden auf ein Ziel, bevor er nur in der History verbleibt.

- 2026-03-25: Streaming- und Final-Qualität im macOS-Diktierpfad weiter angehoben.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `Sources/SessionCore/StreamingCommitStabilizer.swift`, `Tests/SessionCoreTests/StreamingCommitStabilizerTests.swift`
  - Funktionalität: `balanced` und `accurate` nutzen jetzt konservativere Streaming-Commit-Regeln, `finalize` bevorzugt auf höheren Qualitätsstufen das kleinere genauere Modell vor `base`, und der finale Einfügepfad profitiert ebenfalls vom qualitativeren Decode-Setup.

- 2026-03-24: macOS-Shortcut-Recorder um Konfliktwarnungen für System- und Standardbefehle erweitert.
  - Dateien: `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`
  - Funktionalität: Die Settings analysieren frei aufgenommene Hotkeys jetzt gegen bekannte Konflikte wie Spotlight, Eingabequellenwechsel, App-Switcher, Quit und klassische `Command`-Bearbeitungskürzel; problematische Kombinationen werden direkt im UI und in der Diagnose protokolliert.

- 2026-03-24: Streaming-Insert mit konservativerem Commit-Tuning für bessere Teiltranskripte erweitert.
  - Dateien: `Sources/SessionCore/StreamingCommitStabilizer.swift`, `Tests/SessionCoreTests/StreamingCommitStabilizerTests.swift`, `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: Der Stabilizer unterstützt jetzt eine minimale Commit-Erweiterungslänge; `balanced` und `accurate` committen dadurch erst nach stabileren Wiederholungen und längeren Textstücken, während `fast` weiter latenzoptimiert bleibt.

- 2026-03-24: macOS-Hotkey-Auswahl von Presets auf freien Shortcut-Recorder umgestellt.
  - Dateien: `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`
  - Funktionalität: Der globale Diktier-Shortcut wird jetzt direkt in den Settings aufgenommen statt nur aus Presets gewählt; gültige Tasten mit Modifikatoren werden als persistentes Hotkey-Binding gespeichert, im Menü dargestellt und per Carbon-Hotkey registriert.

- 2026-03-24: Streaming-Qualität im macOS-Diktierpfad wirksam verbessert.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `Sources/ASRCore/ASRTypes.swift`, `Sources/ASRCore/WhisperCppEngine.swift`, `Sources/CapabilityCore/CapabilityProfiler.swift`
  - Funktionalität: Capability-Presets steuern jetzt tatsächlich `beamSize`, `threadCount` und `chunkMilliseconds` im `whisper-cli`-Decode; `balanced` und `accurate` liefern im Streaming-Modus dadurch robustere Partial-/Final-Ergebnisse, und `accurate` nutzt im Streaming-Pfad eine qualitativere Decode-Konfiguration statt des bisherigen Minimal-Latenz-Defaults.

- 2026-03-24: macOS-Settings um konfigurierbaren globalen Shortcut und optionale Menüleisten-Hinweise erweitert.
  - Dateien: `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/README.md`
  - Funktionalität: Der globale Diktier-Shortcut ist jetzt als persistente Voreinstellung auswählbar (`Option + Space`, `Control + Space`, `Command + Shift + Space`, `Option + Command + Space`); zusätzlich kann die App Start-/Stop-Hinweise direkt neben dem Menüleisten-Icon anzeigen und blendet den aktiven Shortcut in Menü und Settings sichtbar ein.

- 2026-03-24: macOS-Menüleisten-Steuerung um sichtbares Recording-Label und Notfall-Shortcut erweitert.
  - Dateien: `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/README.md`
  - Funktionalität: Ohne aktivierte Menüleisten-Hinweise zeigt die App während laufender Aufnahme jetzt mindestens `REC` statt nur des statischen App-Namens; zusätzlich ist ein fester Notfall-Shortcut `Control + Option + Escape` registriert, der eine laufende Aufnahme sofort stoppt und in Menü/Settings sichtbar dokumentiert wird.

- 2026-03-24: macOS-Settings um Suchfeld und gefilterte Sections ergänzt.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/README.md`
  - Funktionalität: Die Settings lassen sich jetzt direkt nach Themen wie `hotkey`, `berechtigungen`, `diagnose`, `history` oder `lizenz` filtern; dadurch sind Shortcut-, Permission- und Diagnose-Einstellungen in der Menüleisten-App schneller auffindbar.

- 2026-03-23: Lokaler macOS-Release-Preflight für Produktionsvariablen und Bundle-Prüfung ergänzt.
  - Dateien: `scripts/preflight_macos_release.sh`
  - Funktionalität: Vor dem eigentlichen Release-Lauf prüft das Skript jetzt Produktionsvariablen (`WISPR_LICENSE_PUBLIC_KEY_BASE64`, `SPARKLE_FEED_URL`, `SPARKLE_PUBLIC_ED_KEY`), regeneriert das macOS-Xcode-Projekt, validiert Runtime-Assets und stellt sicher, dass die generierte Projektversion dem Repo-`VERSION`-Stand entspricht.

- 2026-03-22: macOS-Produktionspfad um Bundle-Konfiguration, Auto-Updater und Diagnose-Export erweitert.
  - Dateien: `apps/macos/WisprLocalMac/project.yml`, `apps/macos/WisprLocalMac/WisprLocalMac-Info.plist`, `apps/macos/AppShell/MacAppConfiguration.swift`, `apps/macos/AppShell/SparkleUpdaterController.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`
  - Funktionalität: Die macOS-App liest jetzt Produktionskonfiguration für Lizenz-Public-Key und Sparkle-Update-Feed aus dem Bundle, zeigt den Updater in Menü/Settings an, kann Diagnosen und Audit-Logs exportieren und bildet Lizenzstatus sauber als konfiguriert/nicht konfiguriert/aktiv/ungültig ab.

- 2026-03-22: Reproduzierbarer macOS-Exportpfad für Release-App, DMG und Sparkle-Appcast ergänzt.
  - Dateien: `scripts/export_macos_release.sh`, `scripts/create_macos_dmg.sh`, `scripts/generate_sparkle_appcast.sh`, `scripts/generate_macos_xcodeproj.sh`, `scripts/preflight_macos_release.sh`
  - Funktionalität: Nach dem Archive-Schritt kann das Release jetzt per Skript in `artifacts/mac/release` exportiert, als `.dmg` verpackt und in einen Sparkle-kompatiblen Appcast-Workflow überführt werden; ein neuer Preflight prüft davor Produktionsvariablen, Runtime-Assets und die generierte macOS-Projektmetadaten.

- 2026-03-20: Reproduzierbarer macOS-Smoke-Test für den echten App-Start ergänzt.
  - Dateien: `scripts/smoke_test_macos_app.sh`
  - Funktionalität: Das neue Skript baut `WisprLocalMac` mit Xcode, prüft das erzeugte `.app`-Bundle auf Runtime-Assets (`Runtime/whisper-cli`, ggml-Modelle), startet die App direkt aus dem Bundle und validiert, dass der Prozess mindestens kurz stabil läuft; mit `--keep-running` bleibt die App für manuelle UI-Tests offen.

- 2026-03-20: macOS-Projekt auf versionierte Menüleisten-App und reproduzierbaren Release-Archive-Flow erweitert.
  - Dateien: `apps/macos/WisprLocalMac/project.yml`, `apps/macos/WisprLocalMac/WisprLocalMac-Info.plist`, `scripts/generate_macos_xcodeproj.sh`, `scripts/archive_macos_release.sh`
  - Funktionalität: Die macOS-App wird jetzt als echte Menüleisten-/Agent-App (`LSUIElement`) mit explizitem `CFBundleShortVersionString`/`CFBundleVersion` aus dem Repo-`VERSION`-Stand generiert; Release-Builds aktivieren Hardened Runtime, und ein neues Archive-Skript erstellt reproduzierbar ein Release-`xcarchive` inklusive Runtime-Bundle und Projektgenerierung.

- 2026-03-17: macOS-AppShell um klarere Betriebs-, Diagnose- und Berechtigungsoberfläche erweitert.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/GlobalHotkeyManager.swift`
  - Funktionalität: Menüleisten-App und Settings zeigen jetzt Status-Badges, Fortschritt, Permission-Zustände und konkretere Hinweise; Start/Stop, Snippets, History, Lizenz und Live-Diagnostik sind besser auffindbar und der macOS-Insert-Fallback ist sicherer gegen Fokusdrift.

- 2026-03-17: iOS-/iPadOS-Host-App und Keyboard-Extension weiter auf gemeinsamen Shared-State ausgebaut.
  - Dateien: `apps/ios/App/SharedDefaultsKeys.swift`, `apps/ios/App/IOSSharedStorage.swift`, `apps/ios/App/IOSAppState.swift`, `apps/ios/App/WisprLocaliOSApp.swift`, `apps/ios/KeyboardExtension/KeyboardViewController.swift`, `apps/ios/WisprLocaliOS/project.yml`
  - Funktionalität: Host und Keyboard teilen jetzt die aktive Sprache konsistent über Shared Defaults, die Host-App kann letzte Transkripte direkt in Snippets überführen, und die Keyboard-Extension aktualisiert Sprache, Snippets und letztes Transkript robuster beim Wiederauftauchen.

- 2026-03-16: iOS/iPadOS Host-App und Keyboard-Extension von Blueprint auf baubaren Shared-Storage-Stand erweitert.
  - Dateien: `apps/ios/App/WisprLocaliOSApp.swift`, `apps/ios/App/IOSAppState.swift`, `apps/ios/App/IOSSharedStorage.swift`, `apps/ios/KeyboardExtension/KeyboardViewController.swift`, `apps/ios/WisprLocaliOS/project.yml`, `apps/ios/WisprLocaliOS/WisprLocaliOS.entitlements`, `apps/ios/WisprLocaliOS/WisprLocalKeyboard.entitlements`, `scripts/generate_ios_xcodeproj.sh`
  - Funktionalität: Host-App verwaltet Shared-Snippets, Transcript-History und Offline-Lizenzstatus; Keyboard-Extension kann letztes Shared-Transkript und Shared-Snippets in `textDocumentProxy` einfügen; iOS-Xcode-Projekt und App-Group-Konfiguration sind generierbar.

- 2026-03-11: macOS AppShell um produktionsnahe Persistenz- und Betriebsfunktionen erweitert.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/WisprLocalMac/project.yml`, `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj/project.pbxproj`
  - Funktionalität: Persistente User-Settings (Modus/Sprache/Performance), Snippet-Import/Export (JSON), History Copy-All/Export (TXT), lokales Audit-Logging mit Rotation, sowie `LicenseCore`-Integration (Aktivieren/Deaktivieren, Keychain+Cache, lokale Verifikation).

- 2026-03-04: Transkript-History mit Copy/Delete/Clear und lokaler Persistenz ergänzt.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: Finale Transkripte werden als History gespeichert (`Application Support/WisprLocal/transcript-history.json`) und im Settings-Interface mit Copy/Delete/History-leeren bereitgestellt.

- 2026-03-04: macOS-Diktier-Flow auf produktionsnahen Laufzeitpfad erweitert.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`
  - Funktionalität: Start/Stop-Diktat mit immutable Target-Lock, Streaming-Stabilisierung via Commit-Stabilizer, finale Einfügung, AX-Permission-Prompt, optionaler Paste-Fallback, Sprache/Performance-Auswahl und Snippet-Anwendung im Live- und Final-Flow.

- 2026-03-04: Snippet-Management in der macOS-UI mit lokaler Persistenz verdrahtet.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`
  - Funktionalität: Snippet hinzufügen/löschen, persistentes JSON in Application Support, direkte Nutzung im Diktierlauf.

- 2026-03-04: macOS-App-Projekt automatisch generierbar gemacht.
  - Dateien: `apps/macos/WisprLocalMac/project.yml`, `scripts/generate_macos_xcodeproj.sh`, `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj/project.pbxproj`
  - Funktionalität: Erzeugt ein vollständiges macOS-App-Target mit lokaler Package-Abhängigkeit (`ASRCore`) und eingebundenem Runtime-Resource-Ordner.

- 2026-03-04: App-Startup auf gebündelte ASR-Runtime umgestellt.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`
  - Funktionalität: `WhisperCppEngine.loadBundledModel(...)` wird beim Start ausgeführt; Status/Fehler werden im UI-Diagnosefeld sichtbar.

- 2026-03-03: Swift-first Monorepo-Grundstruktur für Offline-Diktierstack erstellt.
  - Dateien: `Package.swift`
  - Funktionalität: Multi-Module Swift Package für `ASRCore`, `AudioCore`, `SessionCore`, `SnippetCore`, `TextTargetMac`, `CapabilityCore`, `LicenseCore` inkl. Testtargets.

- 2026-03-03: ASR-Core und Modellverwaltung implementiert.
  - Dateien: `Sources/ASRCore/ASRTypes.swift`, `Sources/ASRCore/Protocols.swift`, `Sources/ASRCore/ModelRegistry.swift`
  - Funktionalität: Öffentliche ASR-Interfaces, Transcript-Typen, Registry mit SHA-256-Check.

- 2026-03-03: Echte `whisper.cpp`-Runtime über `whisper-cli` integriert.
  - Dateien: `Sources/ASRCore/WhisperCppEngine.swift`, `Sources/ASRCore/WhisperCLIExecutor.swift`, `Sources/ASRCore/WhisperCLIParser.swift`, `Sources/ASRCore/WAVWriter.swift`
  - Funktionalität: Reale lokale Transkription für Datei- und Streamingpfad (WAV-Export -> `whisper-cli` -> JSON-Parsing), inklusive Segment- und Sprachrückgabe.

- 2026-03-03: Gebündelte Runtime-Installation für app-zentrierten Betrieb ergänzt.
  - Dateien: `Sources/ASRCore/BundledWhisperRuntime.swift`, `Sources/ASRCore/WhisperCppEngine.swift`, `Sources/ASRCore/WhisperCLIExecutor.swift`
  - Funktionalität: Runtime-Assets (`Runtime/whisper-cli`, `Runtime/models/*.bin`) können aus App-Resources lokal installiert und ohne externe Nutzerinstallation verwendet werden; `WhisperCppEngine.loadBundledModel(...)` ergänzt.

- 2026-03-03: Audio-Capture-Layer mit AVAudioEngine angelegt.
  - Dateien: `Sources/AudioCore/AVAudioCaptureService.swift`
  - Funktionalität: Mikrofonberechtigung, 16k-Mono-Chunk-Ausgabe, Converter-Pipeline, Interruption-Events.

- 2026-03-03: Session-State-Machine und Streaming-Stabilisierung umgesetzt.
  - Dateien: `Sources/SessionCore/SessionStateMachine.swift`, `Sources/SessionCore/StreamingCommitStabilizer.swift`
  - Funktionalität: Zustände/Events/Invarianten, committed/tail-Handling, idempotente Insert-Operationen.

- 2026-03-03: Snippet-Engine (final + streaming) implementiert.
  - Dateien: `Sources/SnippetCore/SnippetModels.swift`, `Sources/SnippetCore/SnippetStore.swift`, `Sources/SnippetCore/DefaultSnippetMatcher.swift`
  - Funktionalität: Phrase/Wort-Matching, longest-match-wins, locale/case handling, JSON Import/Export.

- 2026-03-03: macOS Text-Target-Layer mit AX-first und optionalem Paste-Fallback aufgebaut.
  - Dateien: `Sources/TextTargetMac/TextTargetTypes.swift`, `Sources/TextTargetMac/AXTextTargetServices.swift`
  - Funktionalität: Focus-Snapshot, immutable Binding, finalize/stream patch insertion, optional Clipboard-Fallback.

- 2026-03-03: Capability-Profiling + Presets implementiert.
  - Dateien: `Sources/CapabilityCore/CapabilityProfiler.swift`
  - Funktionalität: Device-Profiling (CPU/RAM/Thermal), Streaming-/Quality-/Fallback-Presets, Override-Strategien.

- 2026-03-03: Offline-Lizenzierung mit Ed25519-Verifikation und Storage erstellt.
  - Dateien: `Sources/LicenseCore/Base32.swift`, `Sources/LicenseCore/LicenseModels.swift`, `Sources/LicenseCore/LicenseVerifier.swift`, `Sources/LicenseCore/LicenseStore.swift`, `Sources/LicenseCore/LicenseCache.swift`
  - Funktionalität: Lizenzformat `WISPR1-*`, lokale Signaturprüfung, Keychain-Speicherung, lokale Integritäts-Cachelogik.

- 2026-03-03: App-Shell-Blueprints für macOS und iOS/iPadOS ergänzt.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/README.md`, `apps/ios/App/WisprLocaliOSApp.swift`, `apps/ios/KeyboardExtension/KeyboardViewController.swift`, `apps/ios/README.md`
  - Funktionalität: Menüleisten-App-Struktur, Hotkey-Grundgerüst, Settings-UI, iOS Host-App + Keyboard-Extension-Grundlage.

- 2026-03-03: Build- und Integrationsskripte für whisper.cpp ergänzt.
  - Dateien: `scripts/bootstrap_whisper_submodule.sh`, `scripts/build_whisper_xcframework.sh`, `scripts/download_models.sh`
  - Funktionalität: Submodule-Setup, XCFramework-Build, expliziter `whisper-cli`-Build und Modell-Download-Pipeline.

- 2026-03-03: Testgrundlage für Kernmodule erweitert.
  - Dateien: `Tests/ASRCoreTests/WhisperSupportTests.swift`, `Tests/ASRCoreTests/BundledWhisperRuntimeTests.swift`, `Tests/SnippetCoreTests/SnippetMatcherTests.swift`, `Tests/SessionCoreTests/SessionStateMachineTests.swift`, `Tests/LicenseCoreTests/LicenseVerifierTests.swift`, `Tests/CapabilityCoreTests/CapabilityProfilerTests.swift`, `Package.swift`
  - Funktionalität: Unit-Test-Szenarien für WAV/JSON-ASR-Helfer, Runtime-Installer, Snippets, Session-Invarianten, Lizenzprüfung, Capability-Fallback.

## Breaking Changes

- 2026-03-03: Keine Breaking Changes.

## Docs

- 2026-03-23: macOS-Release-Abnahme als explizite Checkliste dokumentiert.
  - Dateien: `docs/macos-release-checklist.md`, `README.md`, `docs/distribution.md`
  - Inhalt: Dokumentiert den vollständigen lokalen Abnahmeweg für `WisprLocalMac` von Produktionsvariablen über Smoke-Test und reale Ziel-Apps bis zu Export, Notarisierung und Sparkle-Appcast.

- 2026-03-22: README, Distribution- und Lizenzdoku auf den neuen macOS-Release-/Updater-Pfad aktualisiert.
  - Dateien: `README.md`, `apps/macos/README.md`, `docs/distribution.md`, `docs/licensing.md`, `docs/permissions-macos.md`
  - Inhalt: Dokumentiert neue Build-Variablen für `WISPR_LICENSE_PUBLIC_KEY_BASE64`, `SPARKLE_FEED_URL` und `SPARKLE_PUBLIC_ED_KEY`, die Skripte für Preflight/Export/DMG/Appcast, den Bundle-basierten Lizenz-Public-Key sowie den Wake-/Permission-Refresh der macOS-App.

- 2026-03-20: README und macOS-Permissions-Guide um den lokalen Smoke-Test ergänzt.
  - Dateien: `README.md`, `docs/permissions-macos.md`
  - Inhalt: Dokumentiert den neuen Befehl `scripts/smoke_test_macos_app.sh`, den `--keep-running`-Modus und den empfohlenen Ablauf, um vor dem manuellen Permission-/UI-Test den gebauten macOS-App-Bundlepfad zu verifizieren.

- 2026-03-20: README und Distribution-Guide auf den neuen macOS-Agent-/Archive-Flow aktualisiert.
  - Dateien: `README.md`, `apps/macos/README.md`, `docs/distribution.md`
  - Inhalt: Dokumentiert, dass `WisprLocalMac` als reine Menüleisten-App ohne Dock-Icon läuft, wie Versionen in das Xcode-Projekt injiziert werden, und wie der Release-Archive-Pfad über `scripts/archive_macos_release.sh` und `scripts/verify_macos_release_bundle.sh` gefahren wird.

- 2026-03-17: Release-Doku und Build-Anleitung auf verifizierbare Distribution erweitert.
  - Dateien: `docs/build-xcframework.md`, `docs/distribution.md`
  - Inhalt: Dokumentiert Fail-Fast-Verhalten des `whisper.cpp`-Build-Skripts, den neuen Prüfpfad über `scripts/verify_macos_release_bundle.sh` sowie die iOS-Archiv-/Provisioning-Schritte für Host-App und Keyboard-Extension.

- 2026-03-16: iOS-README, Distribution und Keyboard-Plan auf generierbares Projekt mit App-Group-Flow aktualisiert.
  - Dateien: `README.md`, `apps/ios/README.md`, `docs/ios-keyboard-plan.md`, `docs/distribution.md`, `docs/system-design.md`
  - Inhalt: Dokumentiert iOS-XcodeGen-Projekt, Host-App/Extension-Rollen, App-Group `group.com.wisprlocal.shared` und den aktuellen Shared-Storage-Stand.

- 2026-03-11: README und Lizenz-Doku auf aktuellen Produktionsstand der macOS-App aktualisiert.
  - Dateien: `README.md`, `docs/system-design.md`, `docs/licensing.md`
  - Inhalt: Dokumentiert Snippet-Import/Export, History-Export, Audit-Log, Lizenz-UI-Flow und Release-Hinweis zur echten Public-Key-Hinterlegung.

- 2026-03-04: README um History-Funktion der macOS-App ergänzt.
  - Dateien: `README.md`
  - Inhalt: Feature-Liste enthält jetzt persistente Transkript-History mit Copy/Delete/Clear.

- 2026-03-04: macOS-Runbook und Permission-Schritte auf den aktuellen App-Flow aktualisiert.
  - Dateien: `README.md`, `docs/permissions-macos.md`, `docs/system-design.md`, `docs/api-design.md`
  - Inhalt: Echte Start-/Permission-/Hotkey-Anleitung, AppShell-Optionsmodell und aktuelle Laufzeitverkabelung dokumentiert.

- 2026-03-04: README/Build-Doku auf „Projektgenerierung + gebündelte Runtime“ erweitert.
  - Dateien: `README.md`, `docs/build-xcframework.md`
  - Inhalt: End-to-End-Ablauf für Runtime-Bundling und Generierung des macOS-Xcode-Projekts ergänzt.

- 2026-03-03: Architektur-, API-, Build-, Permissions-, iOS- und Lizenz-Dokumentation erstellt und auf echte ASR-Runtime aktualisiert.
  - Dateien: `README.md`, `docs/system-design.md`, `docs/api-design.md`, `docs/build-xcframework.md`, `docs/permissions-macos.md`, `docs/ios-keyboard-plan.md`, `docs/licensing.md`, `docs/distribution.md`, `docs/mvp-milestones.md`
  - Inhalt: Vollständige Design-/Umsetzungsgrundlage inkl. Datenflüsse, State-Machine, Plattformgrenzen und Distribution.

- 2026-03-03: Build-/Packaging-Doku für „App-only Installation“ präzisiert.
  - Dateien: `README.md`, `docs/build-xcframework.md`, `docs/api-design.md`, `docs/system-design.md`
  - Inhalt: Klarstellung, dass Endnutzer keine lokale `brew`/`cmake`-Installation brauchen; Entwicklerflow für Runtime-Bundling dokumentiert.

## Chore

- 2026-04-15: Hotkey-Registrierungslogik aus `MacAppState` in eine eigene Facade ausgelagert.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/MacAppStateHotkeyFacade.swift`
  - Inhalt: Die bisher inline gepflegte globale Shortcut-Registrierung wurde in eine fokussierte Facade mit lokalem State-Snapshot verschoben; `MacAppState` bleibt funktionsgleich, ist aber kleiner und leichter zu warten.

- 2026-03-20: Lokale Xcode-Verifikationsartefakte aus dem Repo-Tracking ausgeschlossen.
  - Dateien: `.gitignore`
  - Inhalt: Repo-lokale Xcode-/SwiftPM-Caches unter `.deriveddata/` und `.xcode-home/` werden ignoriert, damit Build-Verifikationen keine unnötigen Git-Änderungen erzeugen.

- 2026-03-17: Testabdeckung und Release-Skripte deutlich erweitert.
  - Dateien: `Tests/ASRCoreTests/ModelRegistryTests.swift`, `Tests/ASRCoreTests/WhisperCLIExecutorTests.swift`, `Tests/LicenseCoreTests/Base32Tests.swift`, `Tests/LicenseCoreTests/LicenseCacheTests.swift`, `Tests/LicenseCoreTests/LicenseKeyCodecTests.swift`, `Tests/LicenseCoreTests/LicenseVerifierTests.swift`, `Tests/SessionCoreTests/SessionStateMachineTests.swift`, `Tests/SessionCoreTests/StreamingCommitStabilizerTests.swift`, `Tests/SnippetCoreTests/SnippetMatcherTests.swift`, `Tests/SnippetCoreTests/SnippetStoreTests.swift`, `scripts/build_whisper_xcframework.sh`, `scripts/verify_macos_release_bundle.sh`, `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj/project.pbxproj`, `apps/ios/WisprLocaliOS/WisprLocaliOS.xcodeproj/project.pbxproj`
  - Inhalt: Neue Regressionstests decken Modellimport, CLI-Argumentaufbau, Lizenz-Codecs/Cache, Snippet-Store und Session-/Streaming-Kantenfälle ab; Release-Skripte prüfen Abhängigkeiten klarer und erlauben nach Signierung/Notarisierung eine explizite Bundle-Verifikation; Xcode-Projekte wurden aus den aktualisierten `project.yml`-Dateien neu generiert.

- 2026-03-16: Generierte Xcode-Projekte aus dem Repo-Tracking ausgeschlossen.
  - Dateien: `.gitignore`
  - Inhalt: `apps/macos/WisprLocalMac/WisprLocalMac.xcodeproj/` und `apps/ios/WisprLocaliOS/WisprLocaliOS.xcodeproj/` werden als generierte Artefakte ignoriert.

- 2026-03-04: `.gitignore` und Runtime-Handling für App-Resources ergänzt.
  - Dateien: `.gitignore`, `scripts/prepare_runtime_bundle.sh`
  - Inhalt: Generierte Runtime-Dateien im App-Resource-Pfad werden nicht als Source-Änderungen erfasst; Packaging-Flow bleibt reproduzierbar.

- 2026-03-03: Generierte Runtime-Binaries aus dem Repo-Tracking ausgeschlossen.
  - Dateien: `.gitignore`
  - Inhalt: `apps/macos/AppShell/Resources/Runtime/` wird ignoriert, damit große lokale Runtime-Artefakte nicht als Source-Änderungen erscheinen.

- 2026-03-03: `.gitignore` präzisiert, um Overblocking zu vermeiden.
  - Dateien: `.gitignore`
  - Inhalt: Broad-Ignore `third_party/` entfernt; stattdessen nur generierte Unterpfade (`third_party/whisper.cpp/build/`, `third_party/whisper.cpp/models/`) sowie top-level Build-/Artifact-Ordner root-anchored ignoriert.

- 2026-03-03: `.gitignore` für große lokale Build-/Vendor-Artefakte erweitert, um massenhafte ungewollte Git-Änderungen zu verhindern.
  - Dateien: `.gitignore`
  - Inhalt: Ausschlüsse für lokale Build-/Artifact-/Model-Pfade und Release-Artefakte (`artifacts/`, `models/`, `build/`, `*.dmg`, `*.pkg`, `*.ipa`, `*.xcarchive`).

- 2026-03-03: Repository-Basiskonfiguration ergänzt.
  - Dateien: `.gitignore`, `.github/workflows/ci.yml`
  - Inhalt: Build/Test-CI-Workflow und allgemeine Ignore-Regeln.

- 2026-03-03: Runtime-Bundling-Skript ergänzt.
  - Dateien: `scripts/prepare_runtime_bundle.sh`
  - Inhalt: Kopiert `whisper-cli` + Modelle in `apps/macos/AppShell/Resources/Runtime` für app-internen Betrieb.
