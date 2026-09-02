# Cortexa — Dokumentationsindex

Überblick über alle technischen Unterlagen im Repo. **Hinweis:** Cortexa ist [proprietäre Software](licensing.md#proprietary); die Dokumentation dient internen Builds, Mitwirkenden und Release-Prozessen — nicht als Lizenz zur Weiterverwendung des Quellcodes.

| Dokument                                                         | Inhalt                                                                    |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [features-and-implementation.md](features-and-implementation.md) | Funktionsumfang nach Plattform und Zuordnung zu Swift-Paketen / AppShell  |
| [system-design.md](system-design.md)                             | Architektur, Datenflüsse, Session-State-Machine, Sicherheit & Performance |
| [api-design.md](api-design.md)                                   | Öffentliche Protokolle, Konfigurationstypen, Pipeline-Reihenfolge         |
| [licensing.md](licensing.md)                                     | Proprietärer Status und interne Weitergabe                                |
| [permissions-macos.md](permissions-macos.md)                     | Mikrofon, Bedienungshilfen, eingeschränkter Modus ohne AX                 |
| [build-xcframework.md](build-xcframework.md)                     | whisper.cpp / XCFramework / Runtime-Bundle                                |
| [distribution.md](distribution.md)                               | macOS-Archive, Export, Notarisierung, DMG, Sparkle, iOS-Build             |
| [macos-release-checklist.md](macos-release-checklist.md)         | Manuelle Abnahme vor Release                                              |
| [ios-keyboard-plan.md](ios-keyboard-plan.md)                     | iOS-Tastatur-Extension, Grenzen vs. macOS                                 |
| [mvp-milestones.md](mvp-milestones.md)                           | Meilensteine / Planungsstand                                              |

Root-[README.md](../README.md): Schnelleinstieg, Build-Befehle, Feature-Kurzliste, Smoke-Tests.

App-spezifische Details:

- [../apps/macos/README.md](../apps/macos/README.md) — Menüleiste, Settings-Struktur, Updater, Betriebshinweise
- [../apps/ios/README.md](../apps/ios/README.md) — Host-App, Keyboard-Extension, App Group

Weitere Dateien im Repo-Root: `changelog.md` (Release Notes für die App-UI), `security_best_practices_report.md` (Sicherheitsreview).
