# Changelog, Versionierung und Dokumentation

## Changelog

Bei **großen** Funktionsänderung Änderung an einer oder mehreren Dateien (Bugfixes, Erweiterungen, neue Features). Kleinere änderungen müssen nicht in den changlog:

1. **Changelog aktualisieren**: Alle Änderungen vollständig in `changelog.md` eintragen.
2. **Kategorien**: Klar trennen zwischen:
   - **Fixes** (Bugfixes)
   - **Features** (neue Funktionen)
   - **Breaking Changes** (wenn zutreffend)
   - **Docs** (nur Dokumentation)
   - **Chore** (Refactor, Dependencies, Tooling)
3. **Inhalt pro Eintrag**: Geänderte/neu erstellte Dateien und die konkrete Funktionalität dokumentieren, **immer mit Datum** (Format: `YYYY-MM-DD`).
4. **Zeitpunkt**: Changelog-Einträge und Versionsbump **am Ende**, nachdem alle Änderungen erfolgreich umgesetzt und getestet sind.

## Versionsbump (nach Changelog)

- **Bugfix**: Version um **0.0.1** erhöhen (Patch).
- **Feature**: Version um **0.1.0** bzw. auf die nächste 0.1-Stufe erhöhen (Minor).
- **Major-Update** (z. B. Branch-Merge, mehrere Features, größere Umstellung): Erhöhung um **0.2.0** oder nach Absprache.
- **Versionen um 1.0.0**: Werden vom Nutzer angekündigt/freigegeben – nicht eigenständig auf 1.0.0 setzen.

## Dokumentation aktualisieren

Bei **größeren** Änderungen die **zugehörige Projekt-Dokumentation** anpassen. Dokumentations-Updates sind erforderlich, wenn:

- Neue API-Endpoints hinzugefügt oder bestehende geändert werden
- Konfigurationsoptionen oder Umgebungsvariablen sich ändern
- Neue Features hinzugefügt werden oder signifikante Feature-Änderungen
- Architektur-Änderungen vorgenommen werden
- Provider hinzugefügt oder geändert werden
- Breaking Changes eingeführt werden

Dokumentation immer konsistent mit dem aktuellen Stand von Code und Konfiguration halten.

## Code-Qualität und Build

- **Keine Lint- und Build-Fehler**: Alle gemeldeten Linter- und Build-Probleme beheben.
- **Nicht durch Entfernen lösen**: Fehler durch echte Behebung lösen, keine Funktionalität entfernen, um Fehler zu „umgehen“.
- **DRY**: Wiederholungen vermeiden, gemeinsame Logik extrahieren.
- **Best Practices**: An etablierte Konventionen und Best Practices des Projekts halten.
- **Wartbarkeit**: Hooks, APIs und Komponenten sinnvoll nutzen, damit das System wartbar und erweiterbar bleibt.

## Effektiver Debug-Workflow (Anti Ping-Pong)

Ziel: Fehlerbehebung in **möglichst wenigen Schleifen** statt kleinteiligem Hin-und-her.

1. **Reproduzieren + Sammeln**
   - Fehler zuerst zuverlässig reproduzieren.
   - Danach **alle aktuell sichtbaren Compiler-/Build-Fehler** sammeln und clustern (nicht nur den ersten fixen).
2. **Batch-Fix statt Einzelfix**
   - Zusammenhängende Fehler in einem Durchlauf beheben (z. B. Imports, Access-Level, API-Änderungen, Split-Refactor-Folgen).
   - Nur bei hohem Risiko in kleine, aber logisch vollständige Pakete teilen.
3. **Lokale Gates vor Rückgabe**
   - Vor Rückmeldung immer mindestens:
     - `swift build` (oder äquivalenter Paket-Build),
     - relevante projektinterne Tests (wenn betroffen),
     - danach macOS Smoke-Build/Smoke-Test.
4. **Rückmeldung mit Restfehlern**
   - Falls etwas offen bleibt: gebündelt als kurze Liste mit klarer Ursache, betroffenen Dateien und nächstem Fix-Paket.
   - Keine Rückgabe nach rein kosmetischen/partiellen Fixes ohne Build-Status.
5. **User nur für echte Blocker einbinden**
   - Nur dann um erneuten Lauf/Logs bitten, wenn ein externer Blocker vorliegt (z. B. Sandbox, Signing, lokale Xcode-Umgebung, Hardware/Permissions).
   - Sonst Fehlerbehebung vollständig selbst bis zum nächsten grünen Gate durchziehen.

## Definition of Done für Refactor/Fix-Pakete

Ein Arbeitspaket gilt erst als abgeschlossen, wenn:

- Build erfolgreich ist,
- betroffene Tests grün sind (oder dokumentiert, warum nicht ausführbar),
- keine neu eingeführten Warn-/Fehlerklassen offen sind,
- Changelog/Doku/Versionierung (falls erforderlich) konsistent aktualisiert wurden.
