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

Der aktuelle öffentliche Vertriebsweg ist ein lokal gebauter Open-Source-DMG für Apple Silicon. Dafür braucht es kein Apple-Developer-Programm, keine Developer-ID und keine Notarisierung. Die App wird ad-hoc signiert, damit ihre Dateien geprüft werden können; macOS kann beim ersten Öffnen eine Freigabe verlangen. Nach Updates kann macOS Mikrofon- oder Bedienungshilfenrechte erneut abfragen. Sparkle/Appcast ist nicht Teil dieses Ablaufs.

### Neue Version bauen und lokal testen

1. Auf dem passenden `feature/...`, `bugfix/...` oder `chore/...`-Branch arbeiten. `main` und andere Worktrees vor Build-Bereinigung prüfen; nie versehentlich deren Artefakte verwenden.
2. Nach erfolgreicher Implementierung und den relevanten Tests `VERSION` nach den obigen Regeln anheben und `changelog.md` mit Datum, geänderten Dateien, Verhalten und neuer Version aktualisieren. Release-Artefakte müssen dieselbe Version tragen.
3. Änderungen für den Build in einem lokalen Commit festhalten, damit das später veröffentlichte Tag genau auf den getesteten Quellstand zeigen kann. Den Commit vor der Nutzerfreigabe nicht pushen.
4. Paket-Build und betroffene Tests ausführen. Danach den Release-DMG auf einem Apple-Silicon-Mac bauen:

   ```bash
   swift build
   swift test
   ./scripts/build_macos_open_source_release.sh
   ```

   Der Build-Aufruf löscht vorher **nur `artifacts/mac/` in diesem Checkout**, initialisiert das angepinnte Whisper-Submodul bei Bedarf und baut App sowie Whisper-CLI als arm64. Er erstellt `artifacts/mac/Cortexa-<VERSION>.dmg`, eine portable `.sha256`-Datei und Installationshinweise. Die Release-App enthält absichtlich kein Modell; Onboarding lädt das Modell beim ersten Start.
5. Vor der Installation Paket und Prüfsumme prüfen:

   ```bash
   hdiutil verify "artifacts/mac/Cortexa-$(cat VERSION).dmg"
   (cd artifacts/mac && shasum -a 256 -c "Cortexa-$(cat ../../VERSION).dmg.sha256")
   ```

   Danach DMG auf dem Ziel-Mac installieren und App starten. Gatekeeper-Freigabe laut Installationshinweisen bestätigen; Modell-Download, Mikrofon, Bedienungshilfen und Diktat praktisch testen. Release nicht veröffentlichen, bevor der Nutzer den Installationstest ausdrücklich freigegeben hat.

### Releases nach PR-Merge oder Änderungen auf `main`

Ein gemergter PR oder ein Commit auf `main` veröffentlicht **nicht automatisch** einen Release. Ein Release wird nur erstellt, wenn eine neue Produktversion mit passendem `VERSION`- und Changelog-Eintrag vorgesehen ist und der Nutzer die Veröffentlichung nach dem Installationstest ausdrücklich freigegeben hat. Reine Dokumentations- oder Prozessänderungen lösen keinen Produktrelease aus.

1. Nach dem Merge `origin/main` frisch abrufen. Den Release aus dem dann aktuellen `main` bauen und prüfen, nicht aus dem alten PR-Branch. Vorher sicherstellen, dass `VERSION` und `changelog.md` den beabsichtigten Release abbilden und `v<VERSION>` weder lokal noch auf GitHub existiert.
2. Swift-Build, relevante Tests und den arm64-DMG auf genau diesem `main`-Commit ausführen. Danach DMG und Prüfsumme prüfen und den DMG installieren sowie praktisch testen. Wurde der PR erst nach einem Branch-Build gemergt oder änderte sich `main` nach dem Build, ist dieser Build veraltet: vom finalen `main`-Commit neu bauen und erneut testen.
3. Vor der Freigabe darf der geprüfte Release-Commit lokal committed bleiben; für die Veröffentlichung muss `origin/main` genau diesen geprüften Commit enthalten. Falls `main` noch nicht gepusht ist, erst nach ausdrücklicher Nutzerfreigabe pushen. Keinen Release-Tag an den PR-Branch oder einen inzwischen überholten `main`-Stand hängen.
4. Den Release-Tag auf den geprüften `main`-Stand setzen und GitHub-Release-Assets hochladen. GitHub akzeptiert beim Erstellen eines Releases hier den Branch-Namen `main`; verwende `--target main`, nicht den Commit-SHA. Direkt danach prüfen, dass der neue Tag tatsächlich auf den geprüften Commit zeigt.

### Nach ausdrücklicher Freigabe veröffentlichen

1. Prüfen, dass der lokale Release-Branch sauber ist, der getestete Commit noch HEAD ist und die Remote-Branch-/Tag-/Release-Lage frisch abgerufen wurde. `v<VERSION>` darf noch nicht existieren; veröffentlichte Versionstags nicht wiederverwenden oder verschieben.
2. Den getesteten Branch-Commit zu `origin` pushen. Nicht eigenständig nach `main` mergen und keinen PR erstellen, solange der Nutzer das nicht angefordert hat. Wenn der Nutzer ausdrücklich einen Merge nach `main` verlangt, gilt der Ablauf unter „Releases nach PR-Merge oder Änderungen auf `main`“; ein bereits gemergter PR wird nicht noch einmal gemergt.
3. GitHub-Release am getesteten Commit anlegen und DMG, Prüfsumme und Installationshinweise anhängen. Release-Hinweise nennen Version, arm64/Apple Silicon, fehlende Developer-ID/Notarisierung, Gatekeeper-Freigabe und Modell-Download beim ersten Start. Beispiel:

   ```bash
   VERSION_VALUE="$(cat VERSION)"
   gh release create "v${VERSION_VALUE}" \
     "artifacts/mac/Cortexa-${VERSION_VALUE}.dmg" \
     "artifacts/mac/Cortexa-${VERSION_VALUE}.dmg.sha256" \
     "artifacts/mac/Cortexa-${VERSION_VALUE}-install-notes.txt" \
     --target main \
     --title "Cortexa ${VERSION_VALUE}" \
     --notes-file /path/to/release-notes.md
   ```

4. GitHub-Release anschließend zurücklesen und die Assets erneut herunterladen. Prüfsumme und Image-Integrität müssen auch für die Downloads gültig sein:

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
5. Den passenden GitHub-Release-Tracker (aktuell Issue #8) mit Release-URL und den noch offenen Update-/Appcast-Punkten kommentieren. Issue nur schließen, wenn alle dortigen Akzeptanzkriterien erfüllt sind.

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
