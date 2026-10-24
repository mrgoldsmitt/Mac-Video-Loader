# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.
Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/) und dieses Projekt hält sich an [Semantic Versioning](https://semver.org/lang/de/).

---

## [0.7.1] - 2026-10-24

### Behoben & Verbessert
- **Behebung des doppelten Fensteröffnens & Stabilität der Prompteingabe**:
  - **Striktes Single-Window-Management**: `RenameStudioWindowManager` verwaltet nun eine direkte Fenster-Referenz (`window: NSWindow?`) und ignoriert asynchrone Doppelaufrufe vollständig. Ein Klick auf Umbenennen bringt stets das existierende Fenster in den Vordergrund, statt ein zweites Fenster im Hintergrund zu instanziieren.
  - **Entfernung redundanter Observer in MainView**: Die doppelten `.onChange`-Handler in `MainView` wurden entfernt, da `DownloadManager` das Fenster bereits verlässlich öffnet.
  - **Fokus-Stabilität der Texteingabe**: `isMovableByWindowBackground` wurde auf `false` gesetzt. Zuvor fing AppKit Mausklicks und Selektionen im Textfeld als Fenster-Drag ab, wodurch der Cursor und Eingabefokus verloren gingen. Das Verschieben des Fensters erfolgt nun sicher und nativ über den Header-Drag-Handle.
  - **Kein vorzeitiges Auslösen bei Enter**: `.onSubmit` wurde vom Prompt-Eingabefeld entfernt, sodass das Drücken von Enter während des Tippens den Abgleich nicht mehr unabsichtlich startet. Der Abgleich startet exklusiv bei Klick auf „Mit KI abgleichen“.
  - **Schnellbereinigung**: Zusätzlicher Lösch-Button (`xmark.circle.fill`) direkt im Prompt-Eingabefeld.
- **Behebung der KI-Abgleich-Auswahl & Prompt-Eingabe im Rename Studio**:
  - **Identitäts-Synchronisation der PopUp-Buttons**: Durch Umstellung aller Enums (`RenameDatabase`, `RenameProcessingMode`, `RenameLanguage`, `AIProvider`, `FileCategoryFilter`) auf `id: Self { self }` und explizites `id: \.self` im ForEach wurde ein macOS-AppKit-Tag-Mismatch behoben, der dazu führte, dass bei Klick auf "✨ KI-Abgleich" fälschlicherweise "AniDB" ausgewählt wurde (und umgekehrt).
  - **Stabile Prompt-Texteingabe**: Das Texteingabefeld für KI-Prompts bleibt nun dauerhaft geöffnet und verliert während des Tippens weder den Fokus noch schließt es sich unerwartet.
  - **Erschütterungsfreies & stabiles Layout**: Völlige Neustrukturierung der Konfigurationsleiste. Die KI-Steuerelemente (`KI-Anbieter`, `Modell` mit Live-Aktualisierung und das flexible `Prompt`-Eingabefeld inkl. `Tipps`-Menü) befinden sich nun in einer separaten, violett hervorgehobenen Zeile 2. Zeile 1 (Verarbeitungsmodus, Engine, Serientitel/Suchbegriff, Sprache) behält feste, ideale Breiten – kein Stauchen oder Springen der Eingabefelder mehr beim Umschalten von Modi oder Engines.
  - **Reibungslose Eingabe ohne UI-Flicker**: Entkopplung des Rename Studio Fensters von hochfrequenten Hintergrund-Download-Fortschritten (`@ObservedObject` zu `let downloadManager`), sodass Hintergrund-Downloads die Tastatureingabe im Rename Studio zu keinem Zeitpunkt unterbrechen.

### Hinzugefügt
- **Frei verschiebbares Fenster für Rename Studio**:
  - Rename Studio öffnet nun in einem eigenständigen macOS-Fenster (`NSWindow` / `RenameStudioWindowManager`) anstatt als fixiertes modales Sheet.
  - Vollständige Bewegungsfreiheit: Das Fenster lässt sich auf beliebige Monitore verschieben, stufenlos in Breite und Höhe skalieren, minimieren und verfügt über macOS-Fenstersteuerelemente sowie `isMovableByWindowBackground` und einen Header-Drag-Handle (`WindowDragHandle`).
  - Ermöglicht paralleles Verfolgen von Downloads im Hauptfenster während der Dateiorganisation.
- **Dynamischer Live-Modellabruf & Modell-Aktualisierung je KI-Anbieter**:
  - **Google Gemini**: Aufnahme des aktuellen `gemini-2.5-flash-lite` ("Gemini 2.5 Flash-Lite") als empfohlenes Standardmodell. Entfernen veralteter/nicht verfügbarer Modell-IDs (`gemini-2.0-flash`, `gemini-2.5-flash`) inklusive automatischer Migration gespeicherter Benutzereinstellungen.
  - **ChatGPT (OpenAI)**: Unterstützung für `gpt-4o-mini`, `gpt-4o`, `o3-mini`, `o1-mini`, `o1` und `gpt-4-turbo`.
  - **Claude (Anthropic)**: Unterstützung für `claude-3-5-haiku-20241022`, `claude-3-7-sonnet-20250219`, `claude-3-5-sonnet-20241022` und `claude-3-opus-20240229`.
  - **Live-Abfrage der Kontomodelle**: Über den Button "Modelle abrufen" bzw. das Aktualisieren-Symbol (`arrow.clockwise`) werden alle für den individuellen API-Key freigeschalteten Modelle direkt von der jeweiligen Anbieter-API geladen und für künftige Sitzungen lokal zwischengespeichert.
  - Automatischer Modell-Abgleich beim Speichern des Schlüssels sowie nach erfolgreichem Verbindungstest.

---

## [0.7.0] - 2026-10-23

### Hinzugefügt
- **Multi-KI-Anbindung (ChatGPT, Claude & Gemini)**:
  - Freie Wahl des KI-Anbieters für intelligente Umbenennungen: **ChatGPT (OpenAI)**, **Claude (Anthropic)** oder **Google Gemini**.
  - Getrennte, sichere Speicherung der API-Keys im macOS-Schlüsselbund (`KeychainService`) für jeden Anbieter.
  - Dynamische Modellauswahl je nach Anbieter (z. B. `gpt-4o-mini`, `gpt-4o`, `o3-mini`, `claude-3-5-haiku`, `claude-3-5-sonnet`, `gemini-2.5-flash`, `gemini-2.5-pro`).
  - Live-Verbindungstest für alle drei Anbieter direkt im Einstellungen-Dialog.
  - Direkte Anbieter- und Modellwahl im Rename Studio inklusive integriertem Schlüssel-Banner falls noch nicht konfiguriert.
- **Rename Studio (Medien- & Serien-Umbenennung)**:
  - Vollständige Integration von Rename Studio mit smarter lokaler Heuristik, optionaler CLI-Anbindung und KI-Unterstützung (ChatGPT, Claude, Gemini) zum Umbenennen und Organisieren von Medien- und Seriendateien.
  - Visuelle Fortschrittsbalken für Analyse/Abgleich und Umbenennungsausführung in Echtzeit (inkl. Prozentanzeige und aktueller Datei).
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
