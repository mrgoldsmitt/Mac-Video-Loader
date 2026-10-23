# Mac Video Loader (MVL) für macOS – v0.5.1

Eine moderne, native Mac-Anwendung in **SwiftUI** im eleganten **Dark Mode** zum Herunterladen von Videos von **beliebigen Webseiten**, aus den **öffentlich-rechtlichen Mediatheken (ARD, ZDF, Arte, 3sat, KiKa etc.)** sowie von **YouTube**. Unterstützt automatische Erkennung bester Videoqualitäten (MP4), Playlist- und Staffelauswahl mit automatischer Ordnerstrukturierung, dauerhafte Warteschlangen-Persistenz, Ausfallsicherheit mit automatischem Resume sowie Tonspur-Extraktion (MP3, M4A, FLAC, WAV, Opus).

---

## Highlights & Features

- **Beschleunigte Container-Optimierung & Watchdog (Neu in v0.5.1):**
  - **Direkte MP4-Streams bevorzugt**: Bei öffentlich-rechtlichen Mediatheken (ZDF, ARD) werden native, progressive MP4-Streams (`http...`) priorisiert, wodurch zeitaufwändige HLS-MPEG-TS-Container-Fixups entfallen.
  - **FFmpeg & StandardInput-Schutz**: Post-Processing-Aufrufe nutzen `-nostdin`, `-threads 0`, `-y` und `standardInput = FileHandle.nullDevice`. Dadurch werden Hänger durch stdin-Prompts oder Google Drive Cloud-Sperren verhindert.
  - **Post-Processing Watchdog**: Sollte eine Container-Optimierung dennoch länger als 60 Sekunden hängen, startet MVL den Prozess automatisch nahtlos mit `--continue` neu (automatisches Fortsetzen ohne manuellen Eingriff).

- **Fehler-Kategorie am Listenende (Neu in v0.5.1):**
  - Fehlgeschlagene Downloads (z. B. gelöschte oder gesperrte Videos) werden übersichtlich in einer eigenen, rot gekennzeichneten Kategorie am Ende der Liste gesammelt.
  - Mit 1-Klick-Buttons: **„Alle wiederholen“** und **„Alle entfernen“** zum schnellen Bereinigen oder erneuten Starten.
  - Ein- und ausklappbar per Klick.

- **Ausfallsicherheit, Auto-Resume & Mac-Ruhezustandsverhinderung:**
  - **Automatischer Download-Fortschritt**: Downloads brechen bei vorübergehenden Verbindungsabbrüchen, WLAN-Wechseln oder Netzwerkpausen nicht mehr ab. yt-dlp wird mit `--continue`, Socket-Timeouts und automatischen Retry-Parametern betrieben.
  - **Exponentieller Backoff & Reconnect-Trigger**: Schlägt eine Verbindung fehl, versucht MVL mit exponentieller Verzögerung automatisch den Wiederanschluss. Der `NetworkMonitorService` erkennt sofort, sobald das Internet wieder verfügbar ist, und setzt die Queue fort.
  - **macOS SleepPreventionService**: Über IOKit Power Assertions (`kIOPMAssertPreventUserIdleSystemSleep`) bleibt der Mac während aktiver Downloads wach. Sobald alle Downloads beendet sind, wird der normale Energiesparmodus sofort wieder freigegeben.

- **Pause-, Fortsetzen- & Überspringen-Steuerung (Neu in v0.5.0):**
  - **Individuelle Pause/Weiter-Buttons**: Jeder Eintrag in der Warteschlange besitzt einen eigenen Pause/Fortsetzen-Button.
  - **Globale Steuerung**: Toolbar-Buttons „Alle pausieren“ und „Alle fortsetzen“ für die gesamte Liste.
  - **Überspringen-Funktion**: Einträge können einzeln übersprungen werden (⏭).
  - **Staffel- & Serien-Überspringen**: Per Rechtsklick-Kontextmenü können alle Folgen einer bestimmten Staffel oder Serie auf einen Klick übersprungen werden.

- **Dauerhafte Warteschlangen-Persistenz & Wiederherstellung (Neu in v0.5.0):**
  - **Automatische Sicherung**: Die Warteschlange wird bei jeder Statusänderung in `~/Library/Application Support/Mac Video Loader/queue.json` gespeichert.
  - **Kein Datenverlust beim Schließen**: Beim Beenden und Neustarten der App wird der exakte Zustand aller offenen, pausierten und fertigen Downloads wiederhergestellt.
  - **Sofortige Wiederherstellung nächtlicher Downloads**: 187 Downloads (122 Folgen *Die Biene Maja* und 65 Folgen *Flash Gordon*) wurden rekonstruiert und stehen direkt in der Queue bereit.

- **Multi-Selektion, Stapel-Aktionen & `.mvl`-Download-Listen (Neu in v0.5.0):**
  - **Mehrfachauswahl per Checkbox**: Beliebige Einträge können angehakt oder per „Alle auswählen“ markiert werden.
  - **Stapel-Aktionsleiste**: Mit einem Klick ausgewählte Downloads gemeinsam starten, pausieren, überspringen oder entfernen.
  - **Download-Listen speichern & öffnen (`.mvl`)**: Warteschlangen können als portable `.mvl`-Dateien exportiert und geteilt werden. Über Menüleiste (Cmd+O / Cmd+S), Toolbar oder Drag-and-Drop direkt in die App ladbar.

- **Dedizierte Ordner für Serien, Staffeln & Playlists:**
  - **Mediatheken-Serien & Staffeln**: Episoden werden automatisch in saubere Verzeichnisstrukturen abgelegt: `<Download-Ordner>/<Serie>/<Staffel>/` (z. B. `Die Biene Maja/Staffel 1/`, `Die Biene Maja/Staffel 2/`).
  - **Playlists**: Alle Videos einer YouTube- oder Web-Playlist werden in einen eigenen Unterordner `<Download-Ordner>/<Playlist-Name>/` einsortiert.
  - **Speicherort-Vorschau**: Im Auswahlfenster wird vor dem Download exakt angezeigt, wohin die Dateien geladen werden.
  - **Ordner-Pille in der Queue**: Die Warteschlange zeigt dezent an, zu welcher Serie oder Playlist die Folge gehört.

- **Universelle Web-Extraktion:**
  - Einfach eine beliebige Webseiten- oder Video-URL einfügen (z. B. Zeitungsseiten, Portale, Vimeo, ARD, ZDF, Arte, YouTube u. v. m.).
  - MVL erkennt die Seite und wählt automatisch die besten Video- und Audiostreams in höchster Qualität.

- **Öffentlich-rechtliche Mediatheken & Ganze Staffeln:**
  - Volle native Integration für **ARD Mediathek, ZDF, Arte, 3sat, KiKa, SWR, WDR, NDR, BR, MDR, Phoenix**.
  - **Ganze Staffeln herunterladen**: Automatische Erkennung kompletter Serien und Staffeln (bis zu 500 Episoden).
  - **Auto-Staffel-Erkennung aus Einzelfolgen**: Wird eine einzelne Mediathek-Folge eingefügt, findet MVL automatisch die gesamte übergeordnete Staffel und bietet 1-Klick-Auswahl.
  - **Staffel-Filter-Chips & Schnellwahl**: Schnelles Wechseln zwischen Staffeln (`Alle`, `Staffel 1`, `Staffel 2` etc.) und *„Nur diese Staffel auswählen“*.
  - **Staffel- & Episoden-Badges**: Visuelle Kennzeichnung mit `Sxx • Exx` im Auswahldialog.

- **Playlist- & Batch-Downloads mit Auswahldialog:**
  - Erkennt YouTube-Playlists sowie Mediathek-Sammlungen automatisch beim Einfügen der URL.
  - **YouTube-Kombi-URLs gefixt**: Erkennt bei Links mit Video & Playlist (`watch?v=...&list=...`) zuverlässig die gesamte Playlist (`--yes-playlist`).
  - **Cookie-Fallback bei Analyse**: TCC-Blockaden (`Operation not permitted`) bei Safari-Cookies führen nicht mehr zum Abbruch, sondern schalten nahtlos auf Fallback um.
  - **Echtzeit-Fortschrittsbalken**: Exakte prozentuale Fortschrittsanzeige mit Titel-Vorschau und Zähler während der Analyse.
  - **Sofortiger Abbruch**: Analyse jederzeit per Button, `Esc` oder `⌘.` sofort abbrechen.
  - **Interaktiver Auswahldialog (`PlaylistSelectionSheet`)**:
    - Anzeige von Titel, Sender-Badge (ARD, ZDF, Arte, YouTube, Web) und Episodenzahl.
    - Gezieltes An- und Abwählen einzelner oder mehrerer Videos über Checkboxen.
    - Schnellwahl über *„Alle auswählen“* und *„Keine auswählen“*.
    - Live-Suchleiste zur sekundenschnellen Filterung nach Episodennamen oder Mitwirkenden.
    - Live-Zähler (*„X von Y Videos ausgewählt“*).
    - Formatwahl für den gesamten Batch (MP4 Video oder reine Audiodatei).

- **Flexible Video-Qualitäten (MP4):**
  - **Max / Beste Qualität**: Bis zu 4K / 8K UHD mit getrennten Video- & Audiostreams, verlustfrei zusammengefügt via FFmpeg.
  - **2K / 1440p**, **Full HD / 1080p** (inkl. 1080p Premium), **HD / 720p**, **SD / 480p**, **360p**.

- **Reiner Audio-Download:**
  - **MP3** (320 kbps)
  - **M4A / AAC** (Standard für Apple Music & macOS/iOS)
  - **FLAC** (verlustfreie Studioqualität)
  - **WAV** (unkomprimiertes PCM)
  - **Opus** (effizientes Web-Audio)

- **Warteschlange (Queue-System):**
  - Mehrere Downloads gleichzeitig oder nacheinander verwalten.
  - Einstellbare maximale parallele Downloads (1 bis 6 gleichzeitige Streams).
  - Stapel-Download (Batch-Modus): Mehrere URLs zeilenweise einfügen.
  - Live-Fortschrittsbalken mit Prozentanzeige, Downloadgeschwindigkeit (`MB/s`) und verbleibender Restzeit (`ETA`).
  - Schnellzugriff „Im Finder anzeigen“ für fertiggestellte Downloads.

- **Browser-Account & Cookie-Integration:**
  - Verknüpfung mit deinem Browser-Account (Safari, Chrome, Brave, Firefox, Edge oder eigene `cookies.txt`).
  - Ermöglicht den Download von **1080p Premium mit erhöhter Bitrate**, **altersbeschränkten Videos (Age-Gate)** sowie geschützten Inhalten.
  - Höchste Sicherheit: Deine Passwörter verbleiben in deinem Browser.
  - Intelligenter Fallback bei macOS-Datenschutzblockaden (TCC).

- **Freie Downloadordner-Wahl:**
  - Standardmäßig unter `~/Downloads/Mac Video Loader`.
  - Jederzeit per Klick über den nativen macOS-Ordnerdialog anpassbar.

---

## Installation & Deinstallation

### 1. Über das Disk-Image (`Mac-Video-Loader.dmg`) - Empfohlen für Weitergabe
Das vorkompilierte Disk-Image bietet das klassische Mac-Installationsfenster (Drag & Drop):
1. Doppelklicke auf **`Mac-Video-Loader.dmg`** im Projektordner.
2. Ziehe **`Mac Video Loader.app`** einfach auf den verknüpften **`Applications`**-Ordner.
3. Das Disk-Image auswerfen – fertig!

---

### 2. In den Programme-Ordner (`/Applications`) installieren
Es gibt zwei einfache Wege:

* **Weg A – Über Doppelklick / Terminal:**
  - Doppelklick auf `Installieren.command` oder im Terminal:
  ```bash
  cd /Pfad/zu/MacVideoLoader
  ./install.sh
  ```
* **Weg B – Direkt in der App:**
  - Klicke oben in der Menüleiste auf **`Mac Video Loader` → `In Programme-Ordner (/Applications) installieren`**
  - Oder öffne die Einstellungen (Zahnrad-Symbol) → Reiter **Allgemein** → Klicke auf **„In /Applications installieren“**.

Nach der Installation steht die App systemweit in **Spotlight** (Cmd+Leertaste), im **Launchpad** und im Finder unter **Programme** zur Verfügung.

---

### 3. Wieder deinstallieren
* **Weg A – Über Doppelklick / Terminal:**
  - Doppelklick auf `Deinstallieren.command` oder im Terminal:
  ```bash
  cd /Pfad/zu/MacVideoLoader
  ./uninstall.sh
  ```
* **Weg B – Direkt in der App:**
  - Klicke in der Menüleiste auf **`Mac Video Loader` → `Aus Programme-Ordner deinstallieren`**.
* **Weg C – Manuell:**
  - Ziehe einfach `Mac Video Loader.app` aus dem Ordner `Programme` in den Papierkorb.

---

## App starten & neu bauen

### 1. App direkt starten
```bash
open "/Applications/Mac Video Loader.app"
```

### 2. Neu kompilieren & DMG erstellen
```bash
# App-Bundle bauen und signieren
./bundle_app.sh

# Portables Disk-Image erstellen
./create_dmg.sh
```

### 3. Release veröffentlichen & deployen (GitHub)
Das Deployment kann wahlweise lokal über das bereitgestellte Skript oder automatisch über GitHub Actions erfolgen:

* **Lokaler 1-Klick-Deploy:**
  ```bash
  # Baut das App-Bundle & DMG, setzt den Git-Tag (z.B. v0.5.1) und lädt das Release auf GitHub hoch
  ./deploy_release.sh
  ```
* **Automatisierte CI/CD-Pipeline (GitHub Actions):**
  Sobald ein Versions-Tag (z. B. `v0.5.1`) gepusht wird, baut GitHub Actions das DMG automatisch auf einem macOS-Runner und veröffentlicht es als GitHub Release.
