# Changelog

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
