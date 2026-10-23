# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.
Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) und dieses Projekt hält sich an [Semantic Versioning](https://semver.org/lang/de/).

---

## [0.7.0] - 2026-10-23

### Hinzugefügt
- **FileBot Rename Studio (Native Integration & Heuristik)**:
  - Vollständige Integration der FileBot CLI-Logik und smarter lokaler Heuristiken zum Umbenennen und Organisieren von Medien- und Seriendateien.
  - Automatischer Post-Download-Banner: Fragt den Nutzer nach Abschluss eines Downloads, ob die Dateien direkt in Serien- oder Staffelstruktur umbenannt werden sollen.
  - Standalone-Modus für bestehende Mac-Ordner: Beliebige lokale Ordner können über die Top-Navigation (`Dateien umbenennen...`) oder per Drag & Drop rekursiv eingelesen und verarbeitet werden.
  - Drei dedizierte Verarbeitungsmodi:
    - `Serienverarbeitung`: Einheitliche Episodennamen (z. B. `{n} - {s00e00} - {t}`).
    - `Staffelverarbeitung`: Automatische Staffelordner-Hierarchien (z. B. `{n}/Staffel {s.pad(2)}/{n} - {s00e00} - {t}`).
    - `Dateien & Markup`: Beliebige Dateitypen nach benutzerdefinierten Schemata, Tokens oder KI-Vorgaben umbenennen.
- **Google Gemini KI-Integration (Plex- & Custom-Optimierung)**:
  - Sichere Verwaltung des Google Gemini API-Keys über den macOS-Schlüsselbund (`KeychainService`).
  - Modell-Auswahl direkt in den Einstellungen und im Rename Studio (`gemini-2.5-flash`, `gemini-2.5-pro`, `gemini-2.0-flash`, etc.).
  - Plex-optimierte Metadaten-Erkennung: Automatische Recherche echter TVDB/TMDb-Episodennummern passend zum Folgentitel (unabhängig vom Anfangsbuchstaben des Titels).
  - Dediziertes KI-Prompt-Eingabefeld mit Ideen-Schnellmenü für individuelle Anweisungen (z. B. Staffel-Vorgaben, Rechnungs- und Fotobenennung).
- **Dateien & Markup Engine**:
  - Live-Kategorie-Filter (`Alle`, `Videos`, `Audio`, `Dokumente`, `Bilder`, `Sonstige`) mit dynamischer Zählung.
  - Schnelle 1-Klick-Markup-Tokens (`{original}`, `{folder}`, `{date}`, `{year}`, `{index.pad(2)}`, `{clean}`, `{lower}`, `{ext}`).
  - Vorlagen-Presets für Dokumente, Fotos und Medien.
  - Selektive Checkbox-Auswahl für jede einzelne Datei.
- **Queue-Optimierung**:
  - Eigene, separate Abschnitte am Ende der Warteschlange für **Erfolgreich abgeschlossene Downloads** sowie **Fehlgeschlagene Downloads** mit Ein-/Ausklappfunktion.

### Behoben
- Behoben: Beseitigung des Fehlers, dass bei lokalen Heuristiken alle Dateien denselben Bezeichner (`S01E01`) erhielten. Die Heuristik erkennt nun Teiltitel, führende Ziffern und fällt auf fortlaufende Nummerierung zurück.
- Behoben: Kein automatischer Abgleich mehr bei Einstellungswechseln – der Abgleich startet ausschließlich auf expliziten Klick auf `Abgleichen` oder Drücken der Enter-Taste.
- Behoben: Korrekte Staffel-Überspringen-Logik (`skipSeries`) im `DownloadManager`.

---

## [0.6.0] - 2026-10-23

### Hinzugefügt
- **Freie Zielordner-Wahl in der Übersicht & Stapel-Download**:
  - Eigener Ordnerwähler direkt in der Haupteingabeleiste vor dem Starten eines Downloads.
  - Flexibler Zielordner im Stapel-Download-Dialog (`BatchAddSheet`).
  - Drag & Drop von Ordnern aus dem Finder direkt in die Zielordner-Leiste.
  - Intelligente Unterordner-Strukturierung bei Playlists und Mediatheken-Staffeln.

---

## [0.5.2] - 2026-10-23

### Hinzugefügt
- Open-Source-Veröffentlichung unter der Creative Commons Lizenz (CC BY-NC 4.0).
- Automatisierte Release- und Deployment-Pipeline via `deploy_release.sh`.
- Datenschutz- und Pfad-Neutralisierung für öffentlichen Code.

---

## [0.5.1] - 2026-10-23

### Hinzugefügt
- Beschleunigte Container-Optimierung für Mediatheken-Streams (bevorzugt progressive MP4).
- FFmpeg-Watchdog zum automatischen Beheben von hängenden Post-Processing-Aufrufen nach 60 Sekunden.
- Fehlgeschlagene Downloads am Listenende mit 1-Klick-Wiederholung.

---

## [0.5.0] - 2026-10-23

### Hinzugefügt
- Individuelle Pause-, Fortsetzen- und Überspringen-Steuerung pro Download.
- Dauerhafte Warteschlangen-Persistenz (`~/Library/Application Support/Mac Video Loader/queue.json`).
- Multi-Selektion und Export/Import von Download-Listen im `.mvl`-Format.
