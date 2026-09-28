# Lizenzierung von Cortexa

## Cortexa

Der Quellcode von Cortexa steht unter der **Apache License, Version 2.0**. Der vollständige Lizenztext liegt in [`LICENSE`](../LICENSE); eine ergänzende Copyright- und Markennotiz steht in [`NOTICE`](../NOTICE).

Cortexa verlangt keine lokale Lizenzschlüssel-Aktivierung. Die optionale Sparkle-Update-Funktion verwendet separat konfigurierte Update-Signaturen.

Die Apache-2.0-Lizenz erlaubt Nutzung, Änderung und Weitergabe unter ihren Bedingungen. Bei Weitergabe müssen insbesondere Lizenz-, Copyright- und NOTICE-Hinweise erhalten bleiben. Sie gewährt keine Markenrechte zur Bewerbung oder Befürwortung anderer Produkte mit dem Namen oder Logo von Cortexa.

## Drittanbieter und Modelle

Die Cortexa-Lizenz ändert nicht die Bedingungen für externe Komponenten oder Modelle. Der macOS-Build bündelt `whisper.cpp` (MIT) und Sparkle (MIT mit zusätzlichen externen Lizenzhinweisen). Parakeet TDT 0.6B v3 (NVIDIA, CC BY 4.0) sowie NeMo-Speech.cpp (Apache-2.0 mit zusätzlichen Drittanbieterbedingungen) werden bei Bedarf separat heruntergeladen.

Die vollständigen gebündelten Hinweise und Attributionen stehen in [`third-party-notices.md`](third-party-notices.md) und in der App unter **Über Cortexa → Lizenzen**. Die NeMo-Runtime behält außerdem ihre mitgelieferten `LICENSE`, `NOTICE` und Drittanbieterhinweise im Cortexa-verwalteten Runtime-Verzeichnis.

Die jeweiligen Upstream-Lizenzen gelten weiterhin für diese Komponenten und Modelle. Bei jeder Weitergabe müssen ihre Copyright-, Lizenz- und NOTICE-Pflichten zusätzlich zur Cortexa-Lizenz erfüllt werden.
