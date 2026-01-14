# LocalWhisper

**Lokale Spracherkennung für macOS - privat, schnell, offline.**

LocalWhisper ist eine minimalistische Menüleisten-App, die gesprochene Sprache in Text umwandelt. Halte einfach eine Taste gedrückt, sprich, und der Text erscheint automatisch dort, wo dein Cursor steht.

---

## Warum LocalWhisper?

### 100% Privat
Deine Stimme verlässt niemals deinen Mac. Keine Cloud, keine Server, keine Datensammlung. Alles passiert lokal auf deinem Gerät.

### Blitzschnell
Dank Apple Silicon Optimierung (Metal GPU) erfolgt die Transkription in Echtzeit. Sprich einen Satz und der Text erscheint sofort.

### Komplett Offline
Funktioniert ohne Internetverbindung. Im Flugzeug, im Zug, im Keller - überall.

### Mehrsprachig
Erkennt automatisch Deutsch, Englisch und über 90 weitere Sprachen. Wechsle einfach die Sprache während du sprichst.

### Einfache Bedienung
Keine komplizierte Einrichtung. Taste drücken → Sprechen → Taste loslassen → Fertig.

### Unsichtbar
Läuft dezent in der Menüleiste. Kein Dock-Icon, keine störenden Fenster. Da wenn du es brauchst, unsichtbar wenn nicht.

---

## So funktioniert's

1. **Starte LocalWhisper** - Das App-Icon erscheint in deiner Menüleiste
2. **Halte die Option-Taste (⌥) gedrückt** - Die Aufnahme beginnt
3. **Sprich deinen Text** - "Schreibe eine E-Mail an Max..."
4. **Lass die Taste los** - Der Text wird transkribiert und eingefügt

Das war's. Keine Buttons, keine Menüs, keine Ablenkung.

---

## Perfekt für

- **Schnelles Schreiben** - E-Mails, Notizen, Nachrichten diktieren
- **Längere Texte** - Berichte, Dokumentationen, Artikel verfassen
- **Accessibility** - Für alle, die lieber sprechen als tippen
- **Entwickler** - Code-Kommentare und Dokumentation schnell erfassen
- **Kreative** - Ideen festhalten bevor sie verfliegen

---

## Anforderungen

- macOS 13.0 oder neuer
- Apple Silicon Mac (M1, M2, M3, ...)
- Mikrofon-Berechtigung
- Accessibility-Berechtigung (für Text-Einfügung)
- Internetverbindung beim ersten Start (Modell-Download)

---

## Modelle

Beim ersten Start lädt LocalWhisper das WhisperKit-Modell **large-v3-turbo** automatisch herunter und zeigt den Downloadstatus an. Optional kannst du das Modell vorab lokal bereitstellen:

- `~/Library/Application Support/LocalWhisper/WhisperKitModels/<model-name>`
- `Resources/WhisperKitModels/<model-name>` (im App-Bundle)

---

## Datenschutz

LocalWhisper wurde mit Datenschutz als oberste Priorität entwickelt:

- **Nur einmaliger Modell-Download** - Danach läuft die App vollständig offline
- **Keine Telemetrie** - Keine Nutzungsdaten, keine Analytics
- **Keine Speicherung** - Audio wird nach der Transkription sofort verworfen
- **Open Source** - Der komplette Code ist einsehbar

Deine Worte gehören dir.

---

## Technologie

LocalWhisper nutzt [WhisperKit](https://github.com/argmaxinc/WhisperKit), eine Swift- und Core-ML-optimierte Implementierung für on-device Spracherkennung. Die Modelle laufen vollständig lokal auf Apple Silicon.

---

## Lizenz

MIT License - Frei verwendbar, auch kommerziell.
