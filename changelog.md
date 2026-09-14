# Changelog

## Features

- 2026-09-14: Native macOS-Settings-Navigation, datensparsame Suche und systemnahe Hilfen überarbeitet.
  - Dateien: `apps/macos/AppShell/SettingsTab.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/SettingsSearchPresentation.swift`, `apps/macos/AppShell/SearchResultsSettingsPage.swift`, `apps/macos/AppShell/SettingsChromeComponents.swift`, `apps/macos/AppShell/SettingsViewAIProviderSections.swift`, `apps/macos/AppShell/SettingsWindowPresenter.swift`, `Tests/AppShellSupportTests/SettingsTabTests.swift`, `Tests/AppShellSupportTests/SettingsSearchPresentationTests.swift`, `apps/macos/README.md`, `docs/features-and-implementation.md`, `VERSION`
  - Funktionalität: Settings sind nun in lokalisierte Sidebar-Gruppen aufgeteilt, merken sich den zuletzt verwendeten Bereich und öffnen Suchtreffer als gezielte Bereichsnavigation statt vollständige Formulare zusammenzumontieren. Die Suche liest keine persönlichen Diktat-, Wörterbuch- oder Textbaustein-Inhalte mehr. Eigene Hover-Popovers wurden durch native macOS-Hilfe ersetzt; KI-Anbieter werden als kompakte systemnahe Auswahlliste dargestellt. Die Version wurde als Minor-Feature-Release auf `0.30.0` angehoben.

- 2026-09-02: Dynamische Modell-Synchronisierung für Remote-Anbieter ergänzt.
  - Dateien: `apps/macos/AppShell/AIProviderController.swift`, `apps/macos/AppShell/MacAppStateFacadeActions.swift`, `apps/macos/AppShell/SettingsViewAIProviderSections.swift`, `VERSION`
  - Funktionalität: Aktivierte Anbieter synchronisieren ihren Modellkatalog automatisch beim Öffnen der AI-Einstellungen. Zusätzlich kann der ausgewählte Anbieter jederzeit über „Modelle aktualisieren“ manuell synchronisiert werden. Parallel laufende Abrufe werden pro Anbieter zusammengeführt; erfolgreiche leere Antworten entfernen veraltete Modelle, Fehler bleiben sichtbar und behalten die letzte bekannte Liste. Die Version wurde als Feature-Release auf `0.29.0` angehoben.

## Fixes

- 2026-09-14: Settings-Layout bei kleinen Fensterbreiten stabilisiert.
  - Dateien: `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/MacNativeDesign.swift`, `VERSION`
  - Funktionalität: Die Sidebar erhält einen stabilen nativen Innenabstand. Die Modellverwaltung wechselt bei schmalen Detailspalten automatisch von einer einzeiligen Such-/Filterleiste auf eine kompakte zweizeilige Anordnung. Modellzeilen verwenden einen responsiven Fallback für Status und Aktionen; Settings-Buttons nutzen wieder die nativen macOS-Varianten. Die Version wurde als Patch-Bugfix auf `0.30.1` angehoben.

- 2026-09-13: macOS-Berechtigungen bleiben bei korrekt signierten Cortexa-Updates an dieselbe App-Identität gebunden; der Bedienungshilfen-Flow verlangt kein routinemäßiges Entfernen und Neu-Hinzufügen mehr.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/PermissionCoordinator.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `apps/macos/AppShell/BuildPermissionFingerprint.swift` (entfernt), `scripts/archive_macos_release.sh`, `scripts/smoke_test_macos_app.sh`, `scripts/preflight_macos_release.sh`, `Tests/AppShellSupportTests/AppShellCharacterizationTests.swift`, `Tests/AppShellSupportTests/PermissionCoordinatorTests.swift`, `Tests/AppShellSupportTests/BuildPermissionFingerprintTests.swift` (entfernt), `Tests/DocsContractTests/PermissionRecoveryContractTests.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `docs/permissions-macos.md`, `docs/macos-release-checklist.md`, `docs/distribution.md`, `README.md`, `VERSION`
  - Funktionalität: Release-Archive ohne persistente Apple-Signatur werden abgelehnt; nach dem Archivieren prüft das Script Apple-Authority, TeamIdentifier und die Codesign-Integrität. Dadurch können keine ad-hoc-signierten Update-Artefakte mehr die TCC-Identität wechseln. Die App nutzt Apples `AXIsProcessTrustedWithOptions` nur nach einem expliziten Klick auf „Freigabe anfragen“, öffnet dabei direkt die Bedienungshilfen und fragt beim Start eines Diktats nicht wiederholt nach. Die frühere Build-Fingerprint-Heuristik und „Neu verknüpfen“-Banner wurden entfernt, weil sie einen normalen Denial fälschlich als kaputte Verknüpfung behandelten. Der Debug-Smoke-Test kennzeichnet ad-hoc-Signaturen ausdrücklich als ungeeignet für eine Berechtigungs-Persistenz-Aussage. Die Version wurde als Patch-Bugfix auf `0.29.6` angehoben.

- 2026-09-13: Unterbrochene Speech-Modell-Downloads hinterlassen keine verwendbaren Teilmodelle mehr; kombinierte Diktat- und AI-Pfade sind als Testmatrix abgesichert.
  - Dateien: `Sources/ASRCore/VoiceModelInstaller.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/DictationRuntimeServices.swift`, `Tests/ASRCoreTests/VoiceModelDownloadWorkspaceTests.swift`, `Tests/AIProcessingCoreTests/AIProcessingServiceTests.swift`, `Tests/AppShellSupportTests/DictationRuntimeServicesTests.swift`, `Tests/AppShellSupportTests/SessionConfigurationBuilderTests.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `docs/distribution.md`, `VERSION`
  - Funktionalität: Modell-Downloads schreiben erst in einen privaten temporären Ordner und anschließend in eine versteckte Staging-Datei. Erst eine vollständige Datei wird atomar als installierte `.bin` veröffentlicht. Normale Fehler entfernen die Staging-Datei sofort; nach App-Abbruch zurückgebliebene Cortexa-Workspaces und `.partial`-Dateien werden beim nächsten Runtime-Sync gezielt entfernt, ohne fertige Modelle oder fremde temporäre Dateien anzutasten. Die neue Testmatrix prüft Live-/Final-AI an und aus, Streaming-/Finalize- und Clipboard-Zustellung, den Wechsel auf ein neu fokussiertes Textziel, den fehlenden-Ziel-Fallback sowie Promotion, Fehlererhalt und Recovery von Modelldateien. Die Version wurde als Patch-Bugfix auf `0.29.5` angehoben.

- 2026-09-13: Live-Diktate werden beim Stoppen nicht mehr doppelt eingefügt, und neue Diktate verwenden kein veraltetes Textziel mehr.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/DictationRuntimeServices.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `Tests/AppShellSupportTests/DictationRuntimeServicesTests.swift`, `Tests/AppShellSupportTests/SpeechModelControllerTests.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`
  - Funktionalität: Für eine aktive Live-Text-Sitzung ersetzt der Finalpfad den bereits eingefügten Live-Text unabhängig von der allgemeinen Option für simulierte Tastatureingaben. Damit wird das finale ASR- oder AI-Ergebnis nicht zusätzlich hinter den vorläufigen Text gesetzt. Fehlt beim Start oder während des Wartens ein aktuelles Textziel, wartet Cortexa nun auf ein neu fokussiertes Feld statt ein Textfeld einer älteren Sitzung wiederzuverwenden. Fortschritte beim Modell-Download werden nur noch in sinnvollen 5-Prozent-Schritten an den globalen UI-State weitergegeben; das reduziert unnötige Neuaufbauten des offenen Menüleistenmenüs. Die Version wurde als Patch-Bugfix auf `0.29.4` angehoben.

- 2026-09-12: Runtime-Update erkennt gleich große Dateien mit identischem Zeitstempel nun inhaltsbasiert.
  - Dateien: `Sources/ASRCore/BundledWhisperRuntime.swift`, `Tests/ASRCoreTests/BundledWhisperRuntimeTests.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`
  - Funktionalität: Die Synchronisierung vergleicht bei gleichen Dateimetadaten zusätzlich den Inhalt, bevor sie eine vorhandene `whisper-cli` beibehält. Dadurch kann eine veraltete, dynamisch gelinkte CLI nicht mehr als aktuell durchrutschen, wenn ihre Größe und ihr Zeitstempel zufällig mit der korrigierten CLI übereinstimmen. Die Version wurde als Patch-Bugfix auf `0.29.3` angehoben.

- 2026-09-12: Nicht startbare Whisper-Runtime im installierten Cortexa-Bundle behoben und ASR-E2E-Prüfung ergänzt.
  - Dateien: `Sources/ASRCore/BundledWhisperRuntime.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `scripts/build_whisper_xcframework.sh`, `scripts/prepare_runtime_bundle.sh`, `scripts/verify_whisper_cli_runtime.sh`, `scripts/smoke_test_macos_app.sh`, `Tests/ASRCoreTests/BundledWhisperRuntimeTests.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `apps/macos/README.md`, `docs/distribution.md`, `docs/macos-release-checklist.md`, `VERSION`
  - Funktionalität: `whisper-cli` wird statisch gegen Whisper/GGML gebaut und enthält dadurch keine absoluten `@rpath`-Verweise auf den Entwicklungsrechner mehr. Build und Bundle-Vorbereitung lehnen nicht portable dynamische Abhängigkeiten ab und führen einen echten Start-Probe aus. Die App meldet „ASR CLI runtime ready“ erst nach einem erfolgreichen CLI-Start. Der macOS-Smoke-Test transkribiert zusätzlich synthetisierte Sprache mit der CLI und dem Standardmodell aus dem gebauten App-Bundle. Die Version wurde als Patch-Bugfix auf `0.29.2` angehoben.

- 2026-09-11: macOS-Einstellungsfenster stabilisiert und Sidebar-/Glass-Darstellung korrigiert.
  - Dateien: `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/MacNativeDesign.swift`, `VERSION`
  - Funktionalität: Die Sidebar verwendet wieder ausschließlich die native `NavigationSplitView`-/Source-List-Darstellung. Der zusätzliche Hintergrund-Extension-Effekt und der globale Fenster-Hintergrund, die den Liquid-Glass-/Scroll-Edge-Effekt überlagerten, wurden entfernt. Die Sidebar-Breite ist kompakter und verhindert, dass die Detailspalte bei üblichen Fenstergrößen seitlich wegdrückt. Die Version wurde als Patch-Bugfix auf `0.29.1` angehoben.

- 2026-09-02: Wiederholte macOS-Schlüsselbundabfragen beim Öffnen der Einstellungen behoben.
  - Dateien: `apps/macos/AppShell/AIRemoteProviderSecretStore.swift`, `VERSION`
  - Funktionalität: Geladene API-Schlüssel werden innerhalb einer App-Sitzung zwischengespeichert. Dadurch lösen erneute SwiftUI-Neuberechnungen und AI-Stack-Aktualisierungen keine wiederholten Abfragen desselben Schlüsselbund-Eintrags mehr aus. Beim Speichern und Löschen wird der Cache konsistent aktualisiert. Die Version wurde als Patch-Bugfix auf `0.28.1` angehoben.

## Features

- 2026-09-02: Cortexa-Menübar, Modellverwaltung, Dictionary und AppIcon nach UI-Review geschärft.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/SettingsFormPages.swift`, `apps/macos/AppShell/SettingsTab.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/SettingsViewProductivitySections.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `apps/macos/AppShell/SettingsChromeComponents.swift`, `apps/macos/AppShell/MacAppStatePersistenceFacade.swift`, `apps/macos/AppShell/Resources/Assets.xcassets/AppIcon.appiconset`, `scripts/archive_macos_release.sh`, `docs/permissions-macos.md`, `Tests/AppShellSupportTests/AppShellCharacterizationTests.swift`, `Tests/AppShellSupportTests/SpeechModelControllerTests.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`
  - Funktionalität: Nicht installierte Speech-Modelle starten aus der Menüleiste direkt den bestehenden Download-/Auswahlpfad. Die Modellverwaltung enthält Suche sowie Filter für Installationsstatus und Sprachumfang. Sprachlisten sortieren `Auto` immer an erster Stelle. Gespeicherte Dictionary-Begriffe können nachträglich in Begriff, Kategorie und Sprachcode bearbeitet werden; JSON-Import/-Export liegt als Toolbar-Aktion im Dictionary-Tab. Speech- und Advanced-Erklärtexte wurden in den Info-Button verlagert. Berechtigungsstatus werden nutzerfreundlicher als `Freigegeben`/`Nicht freigegeben` angezeigt, inklusive Hinweis auf alte `WisprLocalMac`-TCC-Einträge. Das Statusleistensymbol nutzt explizit monochrome SF-Symbol-Darstellung, das Dock-AppIcon wurde aus den offiziellen Apple-Icon-Composer-Exports aktualisiert, und der lokale Release-Archive-Pfad kann ein validiertes vorhandenes `.xcodeproj` nutzen, wenn `xcodegen` nicht installiert ist. Das macOS-Produkt wird in Info.plist, Xcode-Produkt, App-Bundle, Archiv, DMG und Smoke-Test als `Cortexa` geführt; Target, Scheme, Projektpfad und Bundle-ID `com.wisprlocal.mac` bleiben für technische Kontinuität unverändert. Die Version wurde als Minor-Feature-Release auf `0.28.0` angehoben.
  - Rename-Radius: `apps/macos/WisprLocalMac/project.yml`, `apps/macos/WisprLocalMac/WisprLocalMac-Info.plist`, `scripts/archive_macos_release.sh`, `scripts/export_macos_release.sh`, `scripts/create_macos_dmg.sh`, `scripts/smoke_test_macos_app.sh`, `scripts/generate_sparkle_appcast.sh`, `scripts/generate_macos_xcodeproj.sh`, `README.md`, `docs/distribution.md`, `docs/macos-release-checklist.md` führen die erzeugten Produktartefakte konsistent als `Cortexa.app`, `Cortexa.xcarchive` und `Cortexa.dmg`; technische Target-/Scheme-/Projektpfade und `com.wisprlocal.mac` bleiben unverändert.
  - Sichtbares Branding: `OnboardingView.swift`, `SparkleUpdaterController.swift`, `DiagnosticsController.swift`, `SettingsViewAISections.swift`, `AIProviderController.swift`, `AIProcessingTypes.swift`, `SettingsViewGeneralSections.swift`, `scripts/preflight_macos_release.sh` und die Dokumentationsindizes verwenden `Cortexa`; `Cortexa.icon` ist als primäres Icon-Composer-Asset mit automatischer Appearance-/Fill-Anpassung, Translucency und expliziter heller Dark-Appearance-Glyph-Variante eingebunden, `AppIcon.appiconset` enthält vollständige macOS-Größen im Default-/Light-Modus plus Dark-Luminosity-Varianten, und das About-Fenster rendert das eingebundene `CortexaLogoHorizontal`-Asset adaptiv als Template.
  - Icon-Quelle bereinigt: `apps/macos/AppShell/Resources/Assets.xcassets/AppIcon.appiconset` mit den alten PNG-Dock-Varianten wurde entfernt. Das macOS-Target verwendet ausschließlich `apps/macos/AppShell/Resources/Cortexa.icon`; die sechs gelieferten Appearance-Exporte liegen unverändert unter `cortexa_logos/Icon Exports` als Design-Referenz.

- 2026-07-03: Cortexa-Release-Launch, Menüleisten-Capabilities und Speech-Settings konsolidiert.
  - Dateien: `apps/macos/WisprLocalMac/WisprLocalMac-Info.plist`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SettingsWindowPresenter.swift`, `apps/macos/AppShell/Onboarding/OnboardingWindowPresenter.swift`, `apps/macos/AppShell/SettingsTab.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsFormPages.swift`, `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `Tests/AppShellSupportTests/SpeechModelControllerTests.swift`, `Tests/AppShellSupportTests/SettingsTabTests.swift`, `docs/distribution.md`, `VERSION`
  - Funktionalität: Die App zeigt sichtbar `Cortexa`, behält die technische Bundle-ID bei und öffnet beim ersten sichtbaren Launch ein Settings-/Setup-Fenster, damit Release-/DMG-Starts nicht wie ein No-op wirken. Speech nutzt ein zentrales Modell-Dropdown mit installierbaren Modellen und Bestätigungsdialog; nach Download wird das Modell automatisch ausgewählt. Menüleiste und Settings lesen Sprache/Übersetzung aus denselben Modell-Capabilities, `Auto` bleibt bei English-only-Modellen erhalten, nicht unterstützte Übersetzung wird nicht mehr angeboten, der Menü-Footer wurde entfernt, das Settings-Fenster ist minimierbar und About steht vor Erweitert. Die Version wurde als Minor-Feature-Release auf `0.27.0` angehoben.

- 2026-06-16: macOS First-Run-Onboarding und Release-Bundle ohne gebündeltes Standardmodell.
  - Dateien: `Sources/ASRCore/VoiceModelCatalog.swift`, `Sources/ASRCore/VoiceModelDownloadClient.swift`, `Sources/ASRCore/VoiceModelDownloadProgressMath.swift`, `Sources/ASRCore/VoiceModelInstallProgress.swift`, `Sources/ASRCore/VoiceModelInstaller.swift`, `Sources/ASRCore/BundledWhisperRuntime.swift`, `apps/macos/AppShell/Onboarding/OnboardingStore.swift`, `apps/macos/AppShell/Onboarding/OnboardingCoordinator.swift`, `apps/macos/AppShell/Onboarding/OnboardingWindowPresenter.swift`, `apps/macos/AppShell/Onboarding/OnboardingView.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SessionEntryController.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SettingsChromeComponents.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `scripts/prepare_runtime_bundle.sh`, `scripts/preflight_macos_release.sh`, `scripts/smoke_test_macos_app.sh`, `docs/distribution.md`, `docs/macos-release-checklist.md`, `Tests/ASRCoreTests/VoiceModelCatalogTests.swift`, `Tests/ASRCoreTests/VoiceModelDownloadProgressMathTests.swift`, `Tests/ASRCoreTests/BundledWhisperRuntimeTests.swift`, `Tests/AppShellSupportTests/OnboardingStoreTests.swift`, `Tests/AppShellSupportTests/OnboardingCoordinatorTests.swift`, `Tests/AppShellSupportTests/SpeechModelControllerTests.swift`, `VERSION`
  - Funktionalität: Release-Bundles enthalten nur `whisper-cli` + Manifest (kein `.bin`); das Standardmodell wird im 5-Schritte-Onboarding heruntergeladen. Katalog-Größen und Download-Progress nutzen `expectedDownloadBytes` mit monotoner/indeterminater Anzeige. Bestehende Installationen mit `ggml-base.bin` überspringen Onboarding automatisch. Diktat bleibt gesperrt bis Onboarding und Standardmodell bereit sind.

- 2026-05-19: Lokale Lizenzschlüssel-Aktivierung aus App-Shells und Release-Pfad entfernt.
  - Dateien: `apps/macos/AppShell/MacAppConfiguration.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/DiagnosticsController.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/SettingsFormPages.swift`, `apps/macos/AppShell/SettingsViewAdvancedSections.swift`, `apps/macos/AppShell/SettingsViewSearchSections.swift`, `apps/macos/AppShell/AppShellStoragePaths.swift`, `apps/macos/WisprLocalMac/project.yml`, `apps/macos/WisprLocalMac/WisprLocalMac-Info.plist`, `apps/ios/App/IOSAppState.swift`, `apps/ios/App/WisprLocaliOSApp.swift`, `apps/ios/App/IOSSharedStorage.swift`, `apps/ios/WisprLocaliOS/project.yml`, `scripts/preflight_macos_release.sh`, `scripts/generate_macos_xcodeproj.sh`, `README.md`, `apps/macos/README.md`, `docs/licensing.md`, `docs/distribution.md`, `docs/features-and-implementation.md`, `docs/system-design.md`, `docs/README.md`, `docs/macos-release-checklist.md`, `docs/ios-keyboard-plan.md`, `Tests/DocsContractTests/DocsContractTests.swift`, `Tests/AppShellSupportTests/DiagnosticsControllerTests.swift`, `Tests/AppShellSupportTests/MacAppStateLifecycleAndContextFacadeTests.swift`, `VERSION`
  - Funktionalität: macOS und iOS benötigen keine lokale Lizenzschlüssel-Aktivierung mehr. Die Lizenz-UI, AppState-Verkabelung, Diagnoseausgabe, Info.plist-Keys und Release-Preflight-Pflicht für `WISPR_LICENSE_PUBLIC_KEY_BASE64` wurden entfernt; Shipping benötigt nur noch die Sparkle-Update-Konfiguration (`SPARKLE_FEED_URL`, `SPARKLE_PUBLIC_ED_KEY`).

- 2026-04-14: Funktionsreichen macOS-Settings-/Runtime-Stand für Speech, AI und Provider-Management wiederhergestellt.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsTab.swift`, `apps/macos/AppShell/SettingsFormPages.swift`, `apps/macos/AppShell/SettingsViewShell.swift`, `apps/macos/AppShell/AIProviderController.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/SessionEntryController.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/WisprLocalMac/project.yml`
  - Funktionalität: Die umfangreichen Speech-/AI-Einstellungen sind wieder aktiv (Provider-, Modell- und Formatierungssteuerung inkl. Kontextbewusstsein und Dictionary-Workflows). Zusätzlich wurden die zugehörigen AppShell-Controller und Settings-Komponenten als konsistentes Paket zurückgeführt, damit alle früheren UI- und State-Pfade wieder verfügbar sind.

## Fixes

- 2026-06-18: macOS-App-Export und lokale Smoke-Validierung stabilisiert.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `scripts/smoke_test_macos_app.sh`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`
  - Funktionalität: Der Single-Instance-Guard nutzt unter macOS 14+ die nicht-deprecated Aktivierungs-API, wodurch die Release-Build-Warnung zu `activateIgnoringOtherApps` entfällt. Der macOS-Smoke-Test kann belegte DerivedData-Ordner robust beiseitelegen, statt an kurzzeitig offenen Xcode-Indexdateien abzubrechen. Die Repo-Version wurde als Patch-Bugfix auf `0.26.1` angehoben.

## Chores

- 2026-07-03: Cortexa-Logo als macOS-App-Branding integriert.
  - Dateien: `apps/macos/AppShell/Resources/Assets.xcassets/AppIcon.appiconset`, `apps/macos/AppShell/Resources/Assets.xcassets/CortexaLogoHorizontal.imageset`, `apps/macos/AppShell/Resources/Assets.xcassets/CortexaLogoStacked.imageset`, `apps/macos/AppShell/MenuBarContentView.swift`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`
  - Funktionalität: Das neue Cortexa-Favicon ersetzt die Dock-/AppIcon-PNGs in allen macOS-Größen. Die gelieferten Cortexa-Logo-SVGs liegen nun als Asset-Katalog-Imagesets vor; das Statusleistensymbol selbst nutzt weiterhin ein SF-Symbol. Die Repo-Version wurde als Patch-Chore auf `0.26.3` angehoben.

- 2026-06-30: Eingebettetes `whisper.cpp` auf den benötigten lokalen Runtime-Build reduziert.
  - Dateien: `third_party/whisper.cpp`, `scripts/build_whisper_xcframework.sh`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`
  - Funktionalität: Nicht benötigte upstream-Demos und Beispiele wie `wchess`, Android-, WASM-, Server-, Stream- und Editor-Beispiele sowie upstream-CI-, Test-, Sample-, Binding- und generierte Build-Verzeichnisse wurden entfernt. Erhalten bleibt nur der minimale `whisper-cli`-Build mit den notwendigen Common-Hilfsdateien und CMake-Vorlagen. Der Standard-Build erzeugt jetzt nur noch die lokale macOS-CLI; die XCFramework-Erzeugung bleibt explizit über `ENABLE_XCFRAMEWORK_BUILD=ON` verfügbar. Die Repo-Version wurde als Patch-Chore auf `0.26.2` angehoben.

- 2026-06-16: Fortschrittsanzeige für Speech-Modell-Downloads und klares Entfernen-Feedback in den Settings.
  - Dateien: `Sources/ASRCore/VoiceModelInstallProgress.swift`, `Sources/ASRCore/VoiceModelDownloadClient.swift`, `Sources/ASRCore/VoiceModelInstaller.swift`, `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/SettingsChromeComponents.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/MacAppStateFacadeActions.swift`, `Tests/ASRCoreTests/VoiceModelInstallProgressTests.swift`, `Tests/AppShellSupportTests/SpeechModelControllerTests.swift`, `VERSION`
  - Funktionalität: Modell-Installationen zeigen einen linearen Fortschrittsbalken mit Prozent und übertragenen Bytes. Entfernen zeigt einen „Wird entfernt …“-Zustand, aktualisiert die installierte Modellliste optimistisch und rollt bei Fehlern zurück.

- 2026-06-16: Optionale Speech-Modelle werden nicht mehr fälschlich als installiert angezeigt oder nach Entfernen aus dem App-Bundle zurückkopiert.
  - Dateien: `Sources/ASRCore/BundledWhisperRuntime.swift`, `Sources/ASRCore/VoiceModelInstaller.swift`, `Sources/ASRCore/VoiceModelSuppressionStore.swift`, `scripts/prepare_runtime_bundle.sh`, `Tests/ASRCoreTests/BundledWhisperRuntimeTests.swift`, `Tests/ASRCoreTests/VoiceModelSuppressionStoreTests.swift`, `VERSION`
  - Funktionalität: Das Runtime-Bundle enthält nur noch das Standardmodell (`ggml-base.bin`) plus Manifest. Beim Sync werden nur manifestierte Modelle kopiert; vom Nutzer entfernte optionale Modelle werden persistent unterdrückt und nicht erneut aus dem Bundle wiederhergestellt. Dadurch erscheint z. B. Pro nicht mehr automatisch als installiert, und Entfernen/Installieren verhält sich erwartbar.

- 2026-06-16: macOS-Berechtigungsstatus nach Rebuild/TCC-Mismatch konsistent gemacht und Dev-Start stabilisiert.
  - Dateien: `apps/macos/AppShell/BuildPermissionFingerprint.swift`, `apps/macos/AppShell/PermissionCoordinator.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/AppLifecycleCoordinator.swift`, `apps/macos/AppShell/SettingsWindowPresenter.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/SettingsViewGeneralSections.swift`, `apps/macos/AppShell/SettingsChromeComponents.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `scripts/smoke_test_macos_app.sh`, `Tests/AppShellSupportTests/BuildPermissionFingerprintTests.swift`, `Tests/AppShellSupportTests/PermissionCoordinatorTests.swift`, `README.md`, `VERSION`
  - Funktionalität: Die App erkennt veraltete TCC-Einträge nach Debug-Rebuilds (Build-Fingerprint), refresht Berechtigungen beim Start/Settings-/Menüleisten-Öffnen mehrfach stabilisiert, zeigt „Neu verknüpfen“-Hinweise in Settings und Menüleiste, startet im Smoke-Script per `open(1)` statt direktem Binary-Start und unterstützt `--skip-build` für schnellere lokale Iteration ohne Signatur-Reset.

- 2026-04-20: Menüleisten-AI-Steuerung auf direkte Picker zurückgestellt und LLM-Label ohne statischen Selection-Suffix wiederhergestellt.
  - Dateien: `apps/macos/AppShell/MenuBarContentView.swift`, `VERSION`
  - Funktionalität: Das kompakte LLM-Menü zeigt wieder nur den Titel `LLM Modell` statt eines festen `LLM Modell: ...`-Labels. Die AI-Optionen für Stil, Anrede und Formatierung sind in der nicht-kompakten Menüleiste wieder direkt als Picker verfügbar (nicht als zusätzliche Untermenüs), sodass die Bedienung dem bisherigen Verhalten entspricht.

- 2026-04-20: Startup-Crash durch rekursive Sprachmodell-Sanitization behoben und AI-Auswahlzustände in Menü/Settings klarer sichtbar gemacht.
  - Dateien: `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/SettingsViewAISections.swift`, `VERSION`
  - Funktionalität: Die Sprachmodell-Sanitization setzt Provider/Modell nur noch bei tatsächlicher Änderung, wodurch rekursive `didSet`-Ketten und der daraus resultierende Stack-Overflow-Crash beim App-Start verhindert werden. Zusätzlich zeigt die Menüleiste `Auto` wieder als Sprachoption an und macht aktive LLM-/AI-Auswahlen sichtbarer; in den Settings werden die aktuell gewählten Werte für Stil, Anrede und Formatierung explizit unter den Pickern angezeigt.

- 2026-04-20: Menüleisten-Auswahl für Sprache/LLM/AI-Details wieder klar sichtbar gemacht und `Auto` als Sprachoption korrekt ergänzt.
  - Dateien: `apps/macos/AppShell/MenuBarContentView.swift`, `VERSION`
  - Funktionalität: Die Sprachauswahl in der Menüleiste enthält wieder explizit `Auto`, sodass bei aktivem Auto-Modus kein leerer Zustand mehr angezeigt wird. Zusätzlich zeigt das kompakte LLM-Menü jetzt direkt das aktuell ausgewählte Modell im Label, und die nicht-kompakten AI-Detailmenüs (Stil, Anrede, Format) zeigen den jeweils aktiven Wert sichtbar im Menülabel sowie per Auswahlmarkierung in der Liste.

- 2026-04-20: Voice-Model-Auswahl auf installierte Modelle begrenzt und inkonsistente Modellzustände im Menü/Settings bereinigt.
  - Dateien: `apps/macos/AppShell/SpeechModelController.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/MenuBarContentView.swift`, `apps/macos/AppShell/SettingsViewSpeechDictationSections.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `VERSION`
  - Funktionalität: Nicht installierte Speech-Modelle können im Menüleisten- und Settings-Picker nicht mehr ausgewählt werden. Persistierte/ungültige Modellzustände werden bei der Sanitization wieder auf einen validen Default zurückgeführt, sodass UI-Auswahl und effektive Runtime-Konfiguration konsistenter bleiben. Zusätzlich reagiert der Smoke-Settings-Startup-Hook nur noch auf das explizite Launch-Argument statt auf ein Environment-Flag.

- 2026-04-17: Streaming-/Final-Einfügepfad für schwierige Textfelder stabilisiert und unerwartete Vordergrund-Aktivierung beim Start entschärft.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/DictationRuntimeServices.swift`, `apps/macos/AppShell/SessionEntryController.swift`, `VERSION`, `Tests/DocsContractTests/DocsContractTests.swift`
  - Funktionalität: Für Fallback-Textziele (z. B. IDE-/Electron-Felder ohne zuverlässiges AX-Value-Set) nutzt der Streaming-Pfad jetzt gezielt Paste-Replace über den selektierten AX-Bereich statt nur auf AX-Write zu warten; dadurch werden laufende Aktualisierungen robuster in solchen Controls zugestellt. Final-Insert-Fehler fallen zusätzlich auf einen klaren Clipboard-Backup-Pfad zurück, damit kein finales Transkript verloren geht. Außerdem aktiviert der Restore-Startpfad nicht mehr versehentlich die eigene App als Zielanwendung, was Fokus-/Menu-Bar-Störungen reduziert.

- 2026-04-17: Texteingabe-Robustheit für IDE-/Electron-Ziele verbessert, AI-Live-Fehlerwellen gedrosselt und Stop-Recovery gegen Transkriptverlust ergänzt.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/DictationRuntimeServices.swift`, `VERSION`, `Tests/DocsContractTests/DocsContractTests.swift`
  - Funktionalität: Bei nicht-AX-kompatiblen Textfeldern (z. B. manche IDE-/Electron-Controls) wird jetzt ein fokussiertes Fallback-Ziel für Cmd+V-basierte Einfügung erkannt, statt nur auf AX-Value-Set zu warten. Live-AI-Verarbeitung pausiert nach transienten Verbindungsfehlern kurzzeitig und begrenzt wiederholte Diagnosemeldungen, damit Diktatläufe nicht durch Fehler-Spam überlastet werden. Zusätzlich wird bei `stop`-Fehlern der letzte stabile Live-Text in History/Final-Event gesichert, damit gesprochener Inhalt nicht mehr vollständig verloren geht.

- 2026-04-17: Offene Refactor-Findings für AppState-/Runtime-Entkopplung vollständig geschlossen und gegen Regressionen abgesichert.
  - Dateien: `apps/macos/AppShell/SessionEntryController.swift`, `apps/macos/AppShell/DictationRuntimeEventBridge.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/MacAppStateFacadeActions.swift`, `apps/macos/AppShell/MacAppStatePersistenceFacade.swift`, `Tests/AppShellSupportTests/SessionEntryControllerTests.swift`, `VERSION`, `Tests/DocsContractTests/DocsContractTests.swift`
  - Funktionalität: Der Startpfad nach App-Restore wurde gegen stale async Tasks abgesichert (inkl. explizitem Cancel), Fokus-Wartefehler brechen den Start jetzt deterministisch mit Diagnose/Audit ab, und die Runtime-Event-Bridge vermeidet doppelte Main-Thread-Scheduling-Ketten. Zusätzlich ist die Persistence-Fassade weiter entkoppelt (Datei-Dialog als Presenter, kein Cross-Facade-Normalizer), die Facade-Ownership in `MacAppState` wurde bereinigt und neue Regressionstests decken Abort-/Cancel-Verhalten gezielt ab.

- 2026-04-14: Große Restore-Migration auf funktionsreichen Settings-/Runtime-Stand technisch konsolidiert und Build-Blocker auf aktuelle Core-APIs aufgelöst.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/DictationRuntimeServices.swift`, `apps/macos/AppShell/PermissionController.swift`, `Sources/TextTargetMac/TextTargetTypes.swift`, `Sources/ASRCore/ASRTypes.swift`, `Sources/ASRCore/WhisperCppEngine.swift`, `Sources/TextTargetMac/AXTextTargetServices.swift`, `apps/macos/AppShell/*` (Settings-/Controller-Restore), `Sources/AIProcessingCore/*`, `Sources/ASRCore/VoiceModelCatalog.swift`, `Sources/ASRCore/VoiceModelInstaller.swift`, `Sources/AudioCore/AudioPreprocessor.swift`, `Tests/AIProcessingCoreTests/*`, `Tests/AppShellSupportTests/*`, `Tests/AudioCoreTests/AudioPreprocessorTests.swift`, `apps/macos/WisprLocalMac/project.yml`
  - Funktionalität: Nach der Rückführung auf den reicheren Stand (Basis: `5bc2504`) wurden API-Differenzen zur neueren Core-Schicht gezielt aufgelöst (u. a. `ASRConfig`-Signatur, Entfernung veralteter `onDebugEvent`-Hooks, AX-Permission/Focused-Target-Pfad auf aktuelle `AXTextTargetResolver`-Logik, Sichtbarkeit von `TextTargetSnapshot.element`). Dadurch sind die zuvor aufgetretenen Compilerfehler im AppShell-Pfad behoben und der lokale macOS-Build inkl. Smoke-Test wieder erfolgreich.
  - Rückverfolgbarkeit: Diese Änderung bündelt den Restore des umfangreichen Settings-/Runtime-Pakets mit den notwendigen Kompatibilitätsfixes, damit spätere Qualitätsarbeit auf stabiler Build-Basis erfolgen kann.

- 2026-04-14: AIProcessingCore und Test-Suite auf denselben API-Stand harmonisiert, um Build-/Test-Inkonsistenzen nach dem Restore zu beheben.
  - Dateien: `Sources/AIProcessingCore/AIProcessingTypes.swift`, `Sources/AIProcessingCore/AIProcessingService.swift`, `Sources/AIProcessingCore/AppleFoundationTextProcessor.swift`, `Sources/AIProcessingCore/AIProcessingOutputValidator.swift`, `Sources/AIProcessingCore/OpenAICompatibleRemoteTextProcessor.swift`, `Sources/AIProcessingCore/AppleFoundationPromptBuilder.swift`, `Tests/AIProcessingCoreTests/AIProcessingServiceTests.swift`, `Tests/AIProcessingCoreTests/AppleFoundationPromptBuilderTests.swift`, `Tests/AIProcessingCoreTests/OpenAICompatibleRemoteTextProcessorTests.swift`, `Tests/AppShellSupportTests/*`, `apps/macos/AppShell/MacAppState.swift`
  - Funktionalität: Der Restore wurde auf einen konsistenten Typen-/Provider-Vertrag gebracht, doppelte PromptBuilder-Definitionen wurden entfernt und der lokale AX-Fokus-Zugriff in `MacAppState` auf einen sicheren Cast umgestellt. Dadurch laufen die relevanten Pakettests wieder stabil.

## Fixes

- 2026-04-12: AI-Processing-Initialisierung bereinigt und Kontext-Gating pro Stage stabilisiert.
  - Dateien: `Sources/AIProcessingCore/AIProcessingService.swift`, `Sources/AIProcessingCore/AIProcessingTypes.swift`, `Sources/AIProcessingCore/AppleFoundationTextProcessor.swift`, `Sources/AIProcessingCore/AppleFoundationPromptBuilder.swift`, `Tests/AIProcessingCoreTests/AIProcessingServiceTests.swift`, `Tests/AIProcessingCoreTests/AppleFoundationPromptBuilderTests.swift`
  - Funktionalität: Der bisherige Initialisierungsfehler der AI-Processing-Defaults wurde behoben. Zusätzlich wird App-Kontext jetzt explizit nach `ContextAwarenessMode` (`off`, `finalOnly`, `liveOnly`, `liveAndFinal`) pro Live-/Final-Stage gefiltert, damit unerlaubter Kontext nicht versehentlich in Requests landet.

- 2026-04-02: Sicherheitsrelevante Persistenzpfade gehärtet, Klartext-Lizenzcache entfernt und Clipboard-Tradeoff deutlicher gemacht.
  - Dateien: `Sources/LicenseCore/LicenseStore.swift`, `apps/macos/AppShell/LicenseController.swift`, `apps/ios/App/IOSAppState.swift`, `apps/ios/App/IOSSharedStorage.swift`, `apps/ios/KeyboardExtension/KeyboardViewController.swift`, `Sources/SnippetCore/SecurePersistence.swift`, `Sources/SnippetCore/SnippetStore.swift`, `apps/macos/AppShell/TranscriptHistoryStore.swift`, `apps/macos/AppShell/AuditLogger.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/ios/App/WisprLocaliOSApp.swift`, `docs/licensing.md`, `docs/api-design.md`, `docs/system-design.md`, `README.md`, `Tests/DocsContractTests/DocsContractTests.swift`, `VERSION`
  - Funktionalität: Roh-Lizenzschlüssel werden jetzt nur noch im Keychain gehalten; der bisherige Klartext-Cache-Fallback auf macOS/iOS wird nicht mehr verwendet und alte Cache-Dateien werden bei Nutzung älterer Builds aktiv entfernt, auch wenn zuerst nur die iOS-Keyboard-Extension geöffnet wird. Zusätzlich werden lokale Snippet-, Verlauf-, Audit- und App-Group-Dateien jetzt mit gehärteten Dateirechten bzw. iOS-Dateischutz geschrieben, rotierte/quarantänisierte Dateien nach dem Verschieben erneut gehärtet und der iOS-Transkriptverlauf aus dem Shared-App-Group-Container in host-app-lokalen Speicher verlagert. Der Zwischenablage-Fallback bleibt als absichtlicher Zustellpfad erhalten, wird in der Oberfläche aber explizit als weniger privater Tradeoff kommuniziert.
- 2026-04-01: Lizenz-Deaktivierung, Update-Flow, lokale Persistenz und Runtime-Härtung über macOS-, iOS- und Core-Module hinweg stabilisiert.
  - Dateien: `apps/macos/AppShell/LicenseController.swift`, `Sources/LicenseCore/LicenseCache.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SparkleUpdaterController.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/MacAppConfiguration.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/TranscriptHistoryStore.swift`, `apps/ios/App/IOSSharedStorage.swift`, `apps/ios/App/IOSAppState.swift`, `apps/ios/KeyboardExtension/KeyboardViewController.swift`, `Sources/SnippetCore/SnippetStore.swift`, `Sources/ASRCore/WhisperCLIExecutor.swift`, `Sources/ASRCore/BundledWhisperRuntime.swift`, `Sources/CapabilityCore/CapabilityProfiler.swift`, `Tests/LicenseCoreTests/LicenseCacheTests.swift`, `Tests/SnippetCoreTests/SnippetStoreTests.swift`, `Tests/ASRCoreTests/BundledWhisperRuntimeTests.swift`, `Tests/ASRCoreTests/WhisperCLIExecutorTests.swift`, `Tests/CapabilityCoreTests/CapabilityProfilerTests.swift`
  - Funktionalität: Das Deaktivieren einer Lizenz entfernt auf macOS jetzt nicht nur den Keychain-Eintrag, sondern auch den lokalen Fallback-Cache, damit eine deaktivierte Lizenz nach einem Neustart nicht versehentlich wieder als aktiv erscheint. Der manuelle Update-Check ist in Menüleiste und Settings wieder dauerhaft sichtbar, Feed-URLs werden nur noch über `https` akzeptiert und der Updater nutzt einen typisierten Status statt stringbasierter Sichtbarkeitslogik. Korruptes History-/Snippet-/Shared-Storage-JSON wird in Quarantäne verschoben statt beim nächsten Speichern still überschrieben, iOS koordiniert Shared-Container-Zugriffe jetzt versioniert über `NSFileCoordinator`, und die Keyboard-Extension löscht ihren zuletzt bekannten Zustand bei temporären Lesefehlern nicht mehr. Zusätzlich protokolliert die Runtime keine Rohtranskripte mehr in Diagnostics, Release-Builds lösen `whisper-cli` restriktiver auf, das gebündelte Runtime-Manifest kann optionale SHA-256-Prüfsummen validieren, und das Capability-Profiling vermeidet wiederholte synchrone Benchmark-Kosten durch Caching.

- 2026-04-01: Live-Diktat begrenzt rückwirkende Umschreibungen, verwirft `Blank Audio`-Platzhalter und macht Snippet-Replacements robuster.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `Sources/SessionCore/StreamingCommitStabilizer.swift`, `Sources/SnippetCore/DefaultSnippetMatcher.swift`, `Tests/SessionCoreTests/StreamingCommitStabilizerTests.swift`
  - Funktionalität: Streaming-Updates ersetzen jetzt nur noch den wirklich veränderlichen Textbereich statt den kompletten sichtbaren Satz bei jeder Partial-Antwort neu zu schreiben. Dadurch bleiben ältere Wörter und Sätze stabiler, während der neue `Blank Audio`-Filter leere oder placeholderartige Finals zuverlässig verwirft. Zusätzlich ist der Snippet-Matcher thread-sicherer und behandelt tokenisierte Ersetzungen robuster, damit finale Textersetzungen nicht unnötig an der laufenden Streaming-Logik hängen.

## Features

- 2026-04-12: Dictionary-, Context-Awareness-, ASR-Prompt- und Media-Mute-Upgrade für den macOS-Diktierpfad umgesetzt.
  - Dateien: `apps/macos/AppShell/PersonalDictionaryStore.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `Sources/ASRCore/ASRTypes.swift`, `Sources/ASRCore/WhisperCLIExecutor.swift`, `Sources/ASRCore/WhisperCppEngine.swift`, `Tests/ASRCoreTests/WhisperCLIExecutorTests.swift`, `VERSION`
  - Funktionalität: Die App besitzt jetzt ein persönliches Dictionary mit Kategorien, Import/Export und Review-Queue für Auto-Add-Vorschläge. Dictionary-Terme werden sowohl in der AI-Nachbearbeitung (Begriffserhalt) als auch im ASR-Pfad über einen sicheren Initial-Prompt berücksichtigt. Zusätzlich gibt es einen konfigurierbaren Context-Awareness-Modus in den Settings sowie eine optionale `Mute music while dictating`-Funktion (best-effort Pause/Resume für Apple Music und Spotify). Die Qualitäts-/Formatierungs-Hinweise im Settings-UI wurden für den Live-vs-Final-Tradeoff geschärft.

- 2026-04-02: macOS-Update-Flow für Sparkle + GitHub Releases konzeptionell geschärft und Status-Texte vereinheitlicht.
  - Dateien: `apps/macos/AppShell/SparkleUpdaterController.swift`, `apps/macos/AppShell/MacAppConfiguration.swift`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Der Updater beschreibt jetzt klarer, ob Sparkle verfügbar ist, ob Updates bereits konfiguriert sind, ob gerade geprüft wird oder ob ein neues Release vorliegt. Der manuelle Check setzt den Status nicht mehr dauerhaft auf „Prüfe…“, sondern fällt nach kurzer Zeit wieder in den Bereitschaftszustand zurück, falls Sparkle selbst keine neue Zustandsmeldung liefert. Außerdem wird die Veröffentlichungsquelle in der Konfiguration lesbarer als `GitHub Releases Appcast` beschrieben, und die README erklärt den eingebetteten Sparkle-Flow ohne eigenes Backend.

- 2026-04-02: macOS-Settings um überarbeiteten `About`-Reiter und vorbereitete interne Lizenz-/Support-Gates erweitert.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/MacAppConfiguration.swift`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Die Settings besitzen jetzt einen eigenen `About`-Bereich mit persönlicher Kurzvorstellung auf Basis von `leon-stadler.com/startseite/ueber-mich/`, einer offenen Projektbeschreibung und einem Link zur Website. Support-/Donation-Elemente sowie die Lizenzinfrastruktur bleiben intern vorbereitet, werden aber in öffentlichen Builds nicht angezeigt; Lizenz- und Support-UI erscheinen nur noch über den expliziten `WLMEnableInternalLicenseUI`-Schalter. Der Bereich `Erweitert` konzentriert sich damit öffentlich auf Sparkle-Updates und Diagnose.
  - UI-Polish: Der `About`-Reiter nutzt jetzt eine klarere native Hierarchie mit persönlichem Intro, kurzen Faktenblöcken und einem zurückhaltenden Website-Einstieg statt eines reinen Fließtext-Layouts.

- 2026-04-01: Neue Live-Anpassungs-Einstellung in den macOS-Diktatsettings eingeführt.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/README.md`, `docs/system-design.md`, `VERSION`
  - Funktionalität: In den Einstellungen gibt es jetzt einen sichtbaren Live-Rewrite-Radius von `Nur aktueller Satz` bis `Ganzer aktueller Absatz`. Die Auswahl wird persistent in `UserDefaults` gespeichert und steuert, wie stark die laufende Eingabe bei neuen Partial-Ergebnissen noch umgeschrieben werden darf.

## Docs

- 2026-04-12: API-, System- und README-Dokumentation um Dictionary, Context Awareness, ASR-Initial-Prompt und Media-Mute erweitert.
  - Dateien: `docs/api-design.md`, `docs/system-design.md`, `README.md`, `VERSION`
  - Funktionalität: Die Dokumentation beschreibt nun die erweiterten Dictation-Startoptionen (AI-Konfiguration, Dictionary-Hinweise, optionaler App-Kontext, Media-Mute) sowie die neuen Qualitäts- und Kontextpfade im macOS-AppShell.

- 2026-04-01: API-, System-, Licensing- und README-Verträge an die aktuellen AppShell-Optionen und den manuellen Update-Flow angepasst, und das Repo auf `0.21.0` angehoben.
  - Dateien: `docs/api-design.md`, `docs/system-design.md`, `docs/licensing.md`, `README.md`, `Tests/DocsContractTests/DocsContractTests.swift`, `Package.swift`
  - Funktionalität: Die Dokumentation beschreibt jetzt die aktuellen Dictation-Optionen inklusive `liveRewriteScope`, Delivery-Mode und Clipboard-Fallback, die Mutable-Tail-Semantik beim Streaming, den macOS-Lizenzcache als löschbaren Fallback und den permanent sichtbaren manuellen Update-Check.

## Fixes

- 2026-03-28: macOS-Settings auf natives Segment-Layout umgestellt und Diktier-Runtime gegen Start-/Audio-Fehlerzustände gehärtet.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Das Settings-Fenster nutzt jetzt eine ruhigere native Segmentsteuerung oberhalb der Form-Inhalte, konsistentere deutschsprachige Labels sowie verbesserte VoiceOver-Beschriftungen für Verlauf-/Snippet-Aktionen und gekürzte Vorschautexte. Gleichzeitig verhindert die Runtime Doppelstarts während der Startphase, kann einen Start sauber abbrechen und setzt bei Audio-Push-Fehlern den Session-Zustand vollständig zurück, statt in einem fehlerhaften „läuft bereits“-Zustand zu hängen.

- 2026-03-27: macOS-Diktierpfad unterstützt jetzt den dokumentierten eingeschränkten Modus ohne Bedienungshilfen und zeigt gespeicherte Lizenzen nur noch maskiert an.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/DictationCapability.swift`, `apps/macos/AppShell/PermissionController.swift`, `apps/macos/AppShell/LicenseController.swift`, `apps/macos/AppShell/AuditLogger.swift`, `apps/macos/AppShell/TranscriptHistoryStore.swift`, `README.md`, `VERSION`
  - Funktionalität: Mikrofonzugriff blockiert weiterhin den Aufnahmebeginn, fehlende Bedienungshilfen blockieren aber nicht mehr die Transkription insgesamt; direkte Einfügepfade werden stattdessen sauber auf Verlauf/Zwischenablage degradiert. Gleichzeitig wurden Audit-, History- und Lizenzlogik in eigene Services entkoppelt und gespeicherte Lizenzschlüssel werden nicht mehr ungefragt als Klartext ins UI zurückgeladen.

- 2026-03-27: iOS-Host-App und Keyboard-Extension verwenden jetzt einen expliziten App-Group-Vertrag ohne stillen Local-Fallback, und die Tastatur fügt keine Platzhalter-/Stale-Texte mehr ein.
  - Dateien: `apps/ios/App/IOSSharedStorage.swift`, `apps/ios/App/IOSAppState.swift`, `apps/ios/App/WisprLocaliOSApp.swift`, `apps/ios/KeyboardExtension/KeyboardViewController.swift`, `apps/ios/README.md`, `README.md`, `VERSION`
  - Funktionalität: Die Shared-Container-/Defaults-Auflösung wirft jetzt klare Fehler statt unbemerkt auf lokale Speicherorte auszuweichen; die Extension liest nur noch Snippets plus einen dedizierten Latest-Transcript-Payload und entfernt die bisherige Pseudo-Diktier-/Placeholder-Insertion. Zusätzlich zeigt der Host gespeicherte Lizenzen nur noch maskiert an und entfernt Demo-Transkript-Aktionen aus der Produktionsoberfläche.

## Features

- 2026-03-27: Gebündelte Whisper-Runtime besitzt jetzt einen expliziten Default-Modell-Vertrag und bereinigt veraltete installierte Runtime-Assets automatisch.
  - Dateien: `Sources/ASRCore/BundledWhisperRuntime.swift`, `Tests/ASRCoreTests/BundledWhisperRuntimeTests.swift`, `apps/macos/AppShell/DictationRuntime.swift`, `VERSION`
  - Funktionalität: Die Runtime liest optional ein `runtime-manifest.json`, liefert deterministisch `defaultModelFileName` und `availableModelFileNames`, funktioniert ohne harte `ggml-base.bin`-Annahme und entfernt beim Reinstall nicht mehr referenzierte Modell-Dateien aus dem Zielverzeichnis. Die neuen Tests decken Manifest-Defaults, Fallback-Modelle und Stale-Asset-Pruning ab.

- 2026-03-27: CI- und Release-Tooling validieren jetzt generierte Xcode-Projekte, Release-Konfiguration und headless macOS-Smokes explizit.
  - Dateien: `.github/workflows/ci.yml`, `scripts/generate_macos_xcodeproj.sh`, `scripts/preflight_macos_release.sh`, `scripts/smoke_test_macos_app.sh`, `README.md`, `VERSION`
  - Funktionalität: Die Projektgenerierung unterstützt jetzt `--check`/`--require-clean` statt stiller Auto-Install-/Reuse-Wege, der Release-Preflight prüft zusätzlich Build-/Versions-Metadaten und Asset-Wiring, und der macOS-Smoke-Test kann in CI mit `--skip-launch` Build und Bundle validieren, ohne den App-Prozess offen zu halten.

## Docs

- 2026-03-27: README-Dokumentation auf eingeschränkten macOS-Modus, verpflichtende App Group auf iOS und headless Smoke-Checks aktualisiert.
  - Dateien: `README.md`, `apps/ios/README.md`, `VERSION`
  - Funktionalität: Die Dokumentation beschreibt jetzt den Direct-Insertion-Vorbehalt für Bedienungshilfen, den neuen `--skip-launch`-Pfad für den macOS-Smoke-Test sowie den dedizierten Latest-Transcript-Payload und die fehlende Local-Fallback-Strategie im iOS-App-Group-Flow.

## Fixes

- 2026-03-26: Bundled-Whisper-Runtime akzeptiert im macOS-App-Bundle jetzt sowohl verschachtelte als auch flache Resource-Layouts.
  - Dateien: `Sources/ASRCore/BundledWhisperRuntime.swift`, `Tests/ASRCoreTests/BundledWhisperRuntimeTests.swift`, `apps/macos/WisprLocalMac/project.yml`, `scripts/smoke_test_macos_app.sh`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Die App findet `whisper-cli` und `models/` jetzt sowohl unter `Contents/Resources/Runtime` als auch direkt unter `Contents/Resources`, wodurch Diktierstarts nach XcodeGen-/Asset-Catalog-Anpassungen nicht mehr mit `Bundled runtime directory not found` abbrechen. Zusätzlich bevorzugt das macOS-Projekt wieder die konservative Folder-Resource-Einbindung für `Runtime`, und der Smoke-Test validiert beide Bundle-Varianten.

- 2026-03-26: macOS-Settings und Menüleisten-UI stärker auf native Toolbar-/Form-/Asset-Catalog-Strukturen zurückgeführt.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/WisprLocalMac/project.yml`, `apps/macos/AppShell/Resources/Assets.xcassets/Contents.json`, `apps/macos/AppShell/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`, `apps/macos/AppShell/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`, `apps/macos/AppShell/Resources/Assets.xcassets/AppIcon.appiconset/*.png`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Das Settings-Fenster nutzt jetzt eine native Toolbar-Suche via `.searchable(...)` statt einer selbstgebauten Suchleiste, die Reiterinhalte sind stärker auf `Form`-/`GroupBox`-Verhalten zurückgeführt, und das Menüleisten-Menü gewichtet Primäraktion, Utility-Footer und Status-Pills klarer nach Apple-typischer Bedeutung. Zusätzlich besitzt das macOS-Target jetzt erstmals einen echten Asset Catalog mit `AccentColor` und vollständigem `AppIcon`-Set, der über XcodeGen nativ in das App-Target eingebunden wird.

- 2026-03-26: macOS-Settings- und Menüleisten-Polish nähert die Oberfläche weiter an native Preferences- und Menu-Bar-Gewichtung an.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Das Settings-Fenster nutzt jetzt eine ruhigere Header-Hierarchie mit Kontextzeile, weichere Card-Radien, feinere Abstände und zurückhaltendere Labels; im Menüleisten-Menü wurden Breite, Kartenstärke, Status-Pills, Secondary-Text und Trenner reduziert, damit die Oberfläche weniger boxed und näher an nativer macOS-Preferences-/Menu-Bar-Anmutung wirkt.

- 2026-03-26: macOS-Settings-Suche rendert Bereichstreffer jetzt ohne verschachtelte Reiter-Container und wirkt dadurch deutlich nativer.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Die globale Suche zeigt Treffer jetzt als echte Bereichssektionen statt komplette Pane-Container im Suchmodus; dadurch entfallen die zuvor sichtbare Reiter-/ScrollView-Verschachtelung, die History verhält sich im Suchmodus ohne innere Scrollfläche ruhiger, und das Suchfeld nutzt jetzt lokalisierte Accessibility-Hinweise und eine konsistentere native Interaktion.

- 2026-03-26: macOS-Menü und Settings entfernen doppelten Verlauf, stabilisieren die History-Breite, vereinfachen Menüleisten-Optionen und zeigen Suchtreffer reiterübergreifend.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Das Menü zeigt im Idle-Zustand keinen redundanten `Bereit`-Header und keine doppelte Verlaufsvorschau mehr; die Verlaufsvorschau im Menü wird zusätzlich gekürzt, damit lange Diktate das Layout nicht aufblähen. Die Settings halten jetzt eine feste Fensterbreite, zeigen im History-Reiter kompakte, aufklappbare Verlaufskarten statt ungebremster Volltexte, entfernen den zuvor fest reservierten Notfall-Kurzbefehl vollständig aus Hotkey-Registrierung, UI und Diagnosetexten, blenden den Update-Bereich nicht mehr in den Settings ein und verwenden bei aktiver Suche eine reiterübergreifende Ergebnisansicht mit getrennten Gruppen pro Bereich.

- 2026-03-26: macOS-Settings und Menüleisten-Oberfläche in einem ersten Apple-like-Conformance-Pass visuell und semantisch überarbeitet.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/README.md`, `VERSION`
  - Funktionalität: Die Settings ersetzen große Standard-`Form`-Blöcke jetzt schrittweise durch ruhigere Preference-Cards mit klarerer Hierarchie, kleinerem Header und systemnäherer Fenstergröße; die Suche zeigt eine Trefferzusammenfassung, gruppiert Ergebnisse semantisch und ist für Screenreader klarer ausgezeichnet. Das Menüleisten-Menü nutzt subtilere Status-Pills, leichtere Kartenflächen, eine weniger dominante Kopfzeile und explizitere Accessibility-Auszeichnungen für Status und Sprachwahl.

- 2026-03-25: macOS-Diktierlauf räumt Insert-/AX-Fehler jetzt sauber auf und bleibt bei fehlendem Textziel recoverable.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/MacAppState.swift`, `Sources/ASRCore/Protocols.swift`, `Sources/ASRCore/WhisperCppEngine.swift`
  - Funktionalität: Der Runtime-Pfad hat jetzt einen zentralen Abort/Cleanup-Weg, der Audioengine, Streaming-Decoder, Pending-Insertion-Tasks und Session-Flags zuverlässig zurücksetzt; vorübergehend fehlende oder ungeeignete Textziele werden beim Streaming nicht mehr als fataler Fehler behandelt, sondern halten den bisherigen Text im Wartemodus vor, bis wieder ein editierbares Ziel verfügbar ist.

- 2026-03-25: macOS-Finalisierung speichert Transkripte jetzt unabhängig von der Zustellung immer in der History.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `apps/macos/AppShell/MacAppState.swift`
  - Funktionalität: Finale Diktate werden jetzt als Ereignis mit Zustellungsstatus (`eingefügt`, `Zwischenablage`, `nur History`, `Zustellfehler`) verarbeitet; dadurch bleibt die History auch dann korrekt erhalten, wenn beim Einfügen oder beim Ziel-Timeout kein Textfeld verfügbar war.

- 2026-03-25: Neuer ASR-Lifecycle-Test deckt den Reset-Pfad des Streaming-Engines ab.
  - Dateien: `Tests/ASRCoreTests/WhisperCppEngineLifecycleTests.swift`
  - Funktionalität: Der Test stellt sicher, dass `resetStreaming()` eine laufende Session wirklich zurücksetzt, `stopStreaming()` danach korrekt `engineNotRunning` liefert und ein erneuter Start im selben Engine-Objekt wieder möglich ist.

- 2026-03-25: macOS-Xcode-Projektgenerierung findet Homebrew/XcodeGen jetzt auch außerhalb eines reduzierten PATHs und nutzt vorhandene Projektdateien weiter.
  - Dateien: `scripts/generate_macos_xcodeproj.sh`, `scripts/smoke_test_macos_app.sh`, `VERSION`
  - Funktionalität: Die Skripte suchen `xcodegen` und `brew` jetzt zusätzlich in typischen Homebrew-Pfaden wie `/opt/homebrew/bin`; fehlt `xcodegen` trotzdem, kann der Build auf ein bereits vorhandenes `WisprLocalMac.xcodeproj` zurückfallen, statt unnötig abzubrechen.

- 2026-03-25: macOS-Build-Skripte brechen ohne Homebrew jetzt mit klarer XcodeGen-Anleitung ab.
  - Dateien: `scripts/generate_macos_xcodeproj.sh`, `scripts/smoke_test_macos_app.sh`, `VERSION`
  - Funktionalität: Die Skripte versuchen `brew` nicht mehr blind aufzurufen; wenn weder `xcodegen` noch `brew` verfügbar ist, geben sie eine konkrete Installationsanleitung für XcodeGen aus und stoppen früh mit einer verständlichen Fehlermeldung.

- 2026-03-25: macOS-Settings lassen sich jetzt zuverlässig per globalem Shortcut öffnen.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/MacAppState.swift`
  - Funktionalität: `Control + Option + Escape` stoppt weiterhin laufende Aufnahmen, öffnet im Idle-Zustand jetzt aber tatsächlich das Settings-Fenster; dafür nutzt die App ein eigenes `NSWindow`-basiertes Settings-Presenter statt einer nur visuell angedeuteten Menüleisten-Aktion.

- 2026-03-25: Leerlauf-Halluzinationen wie `Musik` bei fehlendem Sprachsignal im macOS-Diktierpfad gefiltert.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: Der Runtime-Pfad misst jetzt einfache Sprachaktivität per RMS-Schwelle, ignoriert Partials vor gesichertem Spracheinsatz und verwirft sehr kurze bzw. typische Leerlauf-Transkripte ohne ausreichend Sprachenergie statt sie einzufügen oder in die History zu übernehmen.

- 2026-03-25: macOS-Menüleisten-Menü auf Kernaktionen reduziert und visuell bereinigt.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`
  - Funktionalität: Das Menü zeigt jetzt keine langen Status-/Hinweisblöcke mehr; `Check for Updates` ist entfernt, `Open Settings` und `Start Dictation` zeigen ihre Shortcut-Hinweise direkt im Label, und `Letztes Diktat kopieren` ist als Schnellaktion ergänzt.

- 2026-03-25: macOS-Settings auf Reiterstruktur und einklappbare Diagnose umgestellt.
  - Dateien: `apps/macos/AppShell/SettingsView.swift`
  - Funktionalität: Die Settings sind jetzt in Tabs für `General`, `Dictation`, `History`, `Snippets`, `Permissions`, `Diagnostics` und `License` organisiert; die Diagnose wird komprimiert angezeigt, kann aufgeklappt und direkt in die Zwischenablage kopiert werden, und der alte Live-Transkript-Block wurde entfernt.

- 2026-03-25: Menüleisten-Popup gegen unkontrolliertes Anwachsen bei Diagnose-/Fehlertexten gehärtet.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`, `apps/macos/AppShell/MacAppState.swift`
  - Funktionalität: Das `MenuBarExtra` nutzt jetzt eine feste, scrollbare Kompaktansicht; im Fehlerfall wird dort nur noch die letzte relevante Diagnosezeile statt des gesamten Diagnoseverlaufs als Statushinweis angezeigt, wodurch das Popup nicht mehr durch lange Logs auf Bildschirmgröße anwächst.

- 2026-03-25: Deaktivierte Menüleisten-Hinweise blenden den Shortcut-Text jetzt vollständig aus.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`
  - Funktionalität: Wenn `Hinweise in der Menüleiste anzeigen` deaktiviert ist, zeigt die Menüleiste nur noch das Status-Icon und keinen zusätzlichen Start-/Stop- oder Shortcut-Text mehr.

- 2026-03-24: macOS-Diktierstart nutzt zuletzt bekanntes AX-Textziel als Recovery-Pfad.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: Wenn beim Start kurzfristig kein fokussiertes Textfeld geliefert wird, versucht die App jetzt das zuletzt erfolgreich verwendete AX-Textziel im selben Frontmost-App-Kontext erneut zu lesen und dessen aktuellen Cursor-/Selection-Range zu übernehmen, statt den Start sofort scheitern zu lassen.

- 2026-03-24: Menüleisten-Startpfad in der macOS-App von normalem UI-/Hotkey-Start entkoppelt.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`
  - Funktionalität: Der `Start Dictation`-Button im `MenuBarExtra` startet jetzt über einen eigenen verzögerten Ablauf, der erst das Menü schließen lässt, danach die zuletzt aktive App reaktiviert und erst dann die Aufnahme startet; dadurch schlägt der Start aus dem Menü nicht mehr am offenen Menü-Tracking fehl.

- 2026-03-24: Start aus der macOS-Menüleiste gegen verlorenen Textfokus beim Diktierbeginn gehärtet.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/DictationRuntime.swift`
  - Funktionalität: Beim Start über die Menüleiste aktiviert die App jetzt die zuletzt genutzte Fremd-App mit größerem Timing-Puffer erneut und wartet beim AX-Lock mehrere kurze Retry-Zyklen auf ein fokussiertes Textfeld, statt den Diktierstart sofort mit `Kein fokussiertes Textfeld gefunden.` abzubrechen.

- 2026-03-24: macOS-Settings-Fenster in der Menüleisten-App zuverlässig erreichbar gemacht.
  - Dateien: `apps/macos/AppShell/WisprLocalMacApp.swift`
  - Funktionalität: Der Menüpunkt `Open Settings` öffnet jetzt ein explizites `Window(id: "settings")` statt sich auf `showSettingsWindow:` zu verlassen, was in der Agent-/Menüleisten-App zuvor unzuverlässig war.

- 2026-03-24: macOS-Streaming-Insert gegen AppKit/HIToolbox-Absturz durch Queue-Verstoß gehärtet.
  - Dateien: `apps/macos/AppShell/DictationRuntime.swift`, `Sources/TextTargetMac/AXTextTargetServices.swift`
  - Funktionalität: Accessibility-Reads/Writes, Cursor-Updates und Clipboard-Fallbacks laufen jetzt konsistent auf dem Main Thread; dadurch bricht das Diktat beim partiellen oder finalen Einfügen in `NSTextView`-basierte Ziele nicht mehr mit `_dispatch_assert_queue_fail` auf der Queue `wispr.dictation.insert` ab.

- 2026-03-22: macOS-AppShell gegen Main-Actor-/Lifecycle-Probleme und Hotkey-Verlust nach Wake gehärtet.
  - Dateien: `apps/macos/AppShell/MacAppState.swift`, `apps/macos/AppShell/GlobalHotkeyManager.swift`, `apps/macos/AppShell/WisprLocalMacApp.swift`, `scripts/smoke_test_macos_app.sh`
  - Funktionalität: Berechtigungen, Runtime-Initialisierung und Hotkey-Registrierung werden nach App-Aktivierung und System-Wake erneut synchronisiert; der globale Shortcut kann gezielt neu registriert werden, und der Smoke-Test prüft zusätzlich, dass die App als echte Menüleisten-App (`LSUIElement`) gebaut wurde.

- 2026-03-20: iOS-Keyboard-Extension-Paketierung und `whisper.cpp`-XCFramework-Export auf echte Apple-Toolchain-Ausgaben korrigiert.
  - Dateien: `apps/ios/WisprLocaliOS/project.yml`, `apps/ios/WisprLocaliOS/WisprLocaliOS-Info.plist`, `apps/ios/WisprLocaliOS/WisprLocalKeyboard-Info.plist`, `scripts/build_whisper_xcframework.sh`, `Sources/SnippetCore/SnippetStore.swift`, `Tests/SessionCoreTests/StreamingCommitStabilizerTests.swift`
  - Funktionalität: Die Keyboard-Extension nutzt jetzt explizite `Info.plist`-Dateien mit gültigem `NSExtension`-Dictionary (`RequestsOpenAccess`, `PrimaryLanguage`, `IsASCIICapable`) statt flacher Build-Settings, der XCFramework-Wrapper übernimmt nun das tatsächlich von `whisper.cpp` erzeugte `build-apple/whisper.xcframework`, Snippet-Exports erzeugen fehlende Zielordner automatisch, und die Streaming-Stabilizer-Tests spiegeln die produktive Boundary-Commit-Logik korrekt wider.

- 2026-03-20: iOS-Host-App-Target wieder erfolgreich kompilierbar gemacht und echte Xcode-Builds validiert.
  - Dateien: `apps/ios/App/WisprLocaliOSApp.swift`
  - Funktionalität: Optionaler `localeIdentifier` wird in der Snippet-Liste jetzt null-sicher gerendert; danach bauen sowohl das macOS-App-Target (`WisprLocalMac`) als auch das iOS-Projekt mit Keyboard-Extension (`WisprLocaliOS`) erfolgreich per `xcodebuild`.

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
