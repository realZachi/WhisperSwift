# LocalWhisper

**Cloud-basierte Spracherkennung für macOS via Groq API.**

LocalWhisper ist eine minimalistische Menüleisten-App, die gesprochene Sprache in Text umwandelt. Halte einfach eine Taste gedrückt, sprich, und der Text erscheint automatisch dort, wo dein Cursor steht.

---

## Warum LocalWhisper?

### Schnell
Groq liefert Transkriptionen mit hoher Geschwindigkeit und Qualität.

### Einfach
Keine Modell-Downloads, keine komplizierte Einrichtung. API-Key setzen → fertig.

### Mehrsprachig
Whisper-basierte Transkription mit vielen unterstützten Sprachen.

### Leichtgewichtig
Die App bleibt schlank, weil keine großen Modelle lokal gespeichert werden.

### Unsichtbar
Läuft dezent in der Menüleiste. Da wenn du es brauchst, unsichtbar wenn nicht.

---

## So funktioniert's

1. **Starte LocalWhisper** - Das App-Icon erscheint in deiner Menüleiste
2. **Halte die Taste gedrückt** - Die Aufnahme beginnt
3. **Sprich deinen Text**
4. **Lass die Taste los** - Audio wird an Groq gesendet und der Text wird eingefügt

---

## Anforderungen

- macOS 13.0 oder neuer
- Mikrofon-Berechtigung
- Accessibility-Berechtigung (für Text-Einfügung)
- Aktive Internetverbindung
- Groq API Key

---

## Groq API

Die App nutzt den OpenAI-kompatiblen Transcription-Endpoint von Groq:

- API-Key in den Settings eintragen **oder** per `GROQ_API_KEY` Umgebungsvariable
- Standardmodell: `whisper-large-v3-turbo`

---

## Datenschutz

- **Audio wird an Groq übertragen** und dort transkribiert
- **Keine lokale Modellhaltung**
- **Keine Telemetrie**
- **Keine Speicherung** - Audio wird nach der Transkription verworfen

---

## Technologie

LocalWhisper nutzt die Groq API für Whisper-Transkriptionen über HTTPS.

---

## Lizenz

MIT License - Frei verwendbar, auch kommerziell.
