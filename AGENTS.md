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

## macOS-Version, Build und GitHub-Release

Der aktuelle öffentliche Vertriebsweg ist ein von GitHub Actions gebauter Open-Source-DMG für Apple Silicon. Dafür braucht es kein Apple-Developer-Programm, keine Developer-ID und keine Notarisierung. Die App wird ad-hoc signiert, damit ihre Dateien geprüft werden können; macOS kann beim ersten Öffnen eine Freigabe verlangen. Nach Updates kann macOS Mikrofon- oder Bedienungshilfenrechte erneut abfragen. Sparkle/Appcast ist nicht Teil dieses Ablaufs.

### Neue Version bauen und lokal testen

1. Auf dem passenden `feature/...`, `bugfix/...` oder `chore/...`-Branch arbeiten. `main` und andere Worktrees vor Build-Bereinigung prüfen; nie versehentlich deren Artefakte verwenden.
2. Nach erfolgreicher Implementierung und den relevanten Tests `VERSION` nach den obigen Regeln anheben und `changelog.md` mit Datum, geänderten Dateien, Verhalten und neuer Version aktualisieren. Release-Artefakte müssen dieselbe Version tragen.
3. Änderungen für den Build committen und nach `main` pushen. GitHub Actions baut den Release-Kandidaten auf einem frischen Apple-Silicon-Runner von genau diesem `main`-Commit; kein lokales oder altes Branch-Artefakt verwenden.
4. Paket-Build und betroffene Tests ausführen. Danach in GitHub Actions den Workflow **macOS Release** mit `action=prepare` und der Version aus `VERSION` auf `main` starten. Der Workflow baut den arm64-DMG, verifiziert Image und Prüfsumme und erstellt einen GitHub-Draft-Release:

   ```bash
   swift build
   swift test
   ./scripts/build_macos_open_source_release.sh
   ```

   Der lokale Build ist für Entwicklung und Diagnose gedacht und löscht vorher **nur `artifacts/mac/` in diesem Checkout**. Er initialisiert das angepinnte Whisper-Submodul bei Bedarf und erstellt dieselben DMG-, `.sha256`- und Installationshinweis-Dateien wie CI. Die Release-App enthält absichtlich kein Modell; Onboarding lädt das Modell beim ersten Start.
5. Vor der Installation Paket und Prüfsumme prüfen:

   ```bash
   hdiutil verify "artifacts/mac/Cortexa-$(cat VERSION).dmg"
   (cd artifacts/mac && shasum -a 256 -c "Cortexa-$(cat ../../VERSION).dmg.sha256")
   ```

   Den Draft-DMG aus GitHub herunterladen, Prüfsumme und Image-Integrität prüfen, auf dem Ziel-Mac installieren und App starten. Gatekeeper-Freigabe laut Installationshinweisen bestätigen; Modell-Download, Mikrofon, Bedienungshilfen und Diktat praktisch testen. Den Draft erst veröffentlichen, nachdem der Nutzer den Installationstest ausdrücklich freigegeben hat.

### Releases nach PR-Merge oder Änderungen auf `main`

Ein gemergter PR oder ein Commit auf `main` veröffentlicht **nicht automatisch** einen Release. Ein Release wird nur erstellt, wenn eine neue Produktversion mit passendem `VERSION`- und Changelog-Eintrag vorgesehen ist und der Nutzer die Veröffentlichung nach dem Installationstest ausdrücklich freigegeben hat. Reine Dokumentations- oder Prozessänderungen lösen keinen Produktrelease aus.

1. Nach dem Merge `origin/main` frisch abrufen. Vorher sicherstellen, dass `VERSION` und `changelog.md` den beabsichtigten Release abbilden und `v<VERSION>` weder lokal noch auf GitHub existiert.
2. GitHub Actions **macOS Release** auf `main` mit `action=prepare` und `version=<VERSION>` starten. Der Workflow verweigert den Lauf, wenn `main` während des Builds weiterläuft, die Version nicht passt oder Tag/Release schon existiert. Er führt Swift-Build und Tests aus, baut den arm64-DMG und erstellt den Draft am getesteten `main`-Stand.
3. Prüfen, dass der Draft-Tag auf den gebauten Commit zeigt. Draft-Assets herunterladen und Prüfsumme sowie DMG-Integrität unabhängig prüfen. Den DMG installieren und praktisch abnehmen.
4. Nach ausdrücklicher Nutzerfreigabe denselben Workflow auf `main` mit `action=publish` und derselben `version=<VERSION>` starten. Der Workflow veröffentlicht ausschließlich einen passenden Draft, dessen Tag und Quell-Commit im Release-Text übereinstimmen. Er erstellt keinen neuen Build und kann einen bereits veröffentlichten Release nicht erneut veröffentlichen.

### Nach ausdrücklicher Freigabe veröffentlichen

1. Den getesteten Branch-Commit integrieren und nach `main` pushen. PRs werden im Repository deaktiviert; keinen PR erstellen. Nach einem Merge/Push den Workflow-Ablauf oben verwenden.
2. Nach manueller Installation und ausdrücklicher Nutzerfreigabe den Draft über den Workflow `action=publish` veröffentlichen.
3. GitHub-Release anschließend zurücklesen und die Assets erneut herunterladen. Prüfsumme und Image-Integrität müssen auch für die Downloads gültig sein:

   ```bash
   VERSION_VALUE="$(cat VERSION)"
   VERIFY_DIR="$(mktemp -d)"
   gh release view "v${VERSION_VALUE}" --json url,tagName,targetCommitish,assets
   gh release download "v${VERSION_VALUE}" \
     --pattern "Cortexa-${VERSION_VALUE}.dmg" \
     --pattern "Cortexa-${VERSION_VALUE}.dmg.sha256" \
     --dir "${VERIFY_DIR}"
   (
     cd "${VERIFY_DIR}"
     shasum -a 256 -c "Cortexa-${VERSION_VALUE}.dmg.sha256"
     hdiutil verify "Cortexa-${VERSION_VALUE}.dmg"
   )
   ```

   Bei Abweichung Release nicht als erfolgreich melden; Ursache beheben und erneut verifizieren.
4. Den passenden GitHub-Release-Tracker (aktuell Issue #8) mit Release-URL und den noch offenen Update-/Appcast-Punkten kommentieren. Issue nur schließen, wenn alle dortigen Akzeptanzkriterien erfüllt sind.

Wenn ein Release-Asset nach Veröffentlichung korrigiert werden muss, nur das betroffene Asset gezielt ersetzen (`gh release upload ... --clobber`) und danach Download, Prüfsumme und DMG erneut verifizieren. Den Versions-Tag nicht auf einen anderen Commit verschieben.

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
