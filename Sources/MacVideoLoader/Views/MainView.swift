import SwiftUI
import AppKit

public struct MainView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var settings = AppSettings.shared

    @State private var showSettings: Bool = false
    @State private var showBatchSheet: Bool = false
    @State private var isDropTargeted: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // App Navigation / Top Bar
            topNavigationBar
                .sheet(isPresented: $showSettings) {
                    SettingsSheet(settings: settings)
                }

            // Input Bar
            HeaderInputView(
                downloadManager: downloadManager,
                showBatchSheet: $showBatchSheet
            )
            .sheet(isPresented: $showBatchSheet) {
                BatchAddSheet(downloadManager: downloadManager)
            }

            // Analysis Progress Banner (visible when inspecting playlist/URL)
            if downloadManager.isAnalyzingURL {
                analysisBanner
            } else if let errorMsg = downloadManager.analysisError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fehler beim Abrufen der Inhaltsstruktur")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text(errorMsg)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(action: { downloadManager.analysisError = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.18))
            }

            // Rename Studio Post-Download Prompt Banner
            if let promptItem = downloadManager.renamePromptItem {
                postDownloadRenameBanner(for: promptItem)
            }

            // Queue Control Strip
            queueControlStrip

            // Queue List
            QueueListView(downloadManager: downloadManager)

            // Bottom Statusbar
            bottomStatusBar
        }
        .frame(minWidth: 720, minHeight: 520)
        .preferredColorScheme(.dark)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .sheet(item: $downloadManager.detectedPlaylist) { playlist in
            PlaylistSelectionSheet(playlist: playlist, downloadManager: downloadManager)
        }
        .onDrop(of: ["public.file-url", "public.utf8-plain-text", "public.url"], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.1, green: 0.5, blue: 0.95), Color(red: 0.85, green: 0.15, blue: 0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .shadow(color: Color.blue.opacity(0.35), radius: 4, x: 0, y: 1)

                Text("MVL")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Mac Video Loader")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text("MVL")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }

                Text("Nativer Mac Video- & Mediatheken-Downloader (ARD, ZDF, Arte, YouTube & Web)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Standalone Rename Studio Button
            Button(action: openStandaloneFolderPicker) {
                HStack(spacing: 5) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)

                    Text("Dateien umbenennen...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Bestehende Ordner & Dateien rekursiv nach Schema oder KI umbenennen")

            // Account Status Pill
            Button(action: { showSettings = true }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(settings.useCookies ? Color.green : Color.gray.opacity(0.6))
                        .frame(width: 7, height: 7)

                    Text(settings.useCookies ? "Account: \(settings.selectedBrowser.displayName)" : "Kein Account verknüpft")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(settings.useCookies ? .white : .secondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(settings.useCookies ? Color.green.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Account-Cookies für Browser konfigurieren")

            // Settings Button
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Einstellungen öffnen")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }

    // MARK: - Analysis Progress Banner
    private var analysisBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Animated radar/search icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.18))
                        .frame(width: 36, height: 36)

                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Webseite & Playlist wird analysiert...")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        if let total = downloadManager.analysisTotalItems, total > 0 {
                            Text("\(downloadManager.analysisItemsFound) von \(total) Titeln")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        } else if downloadManager.analysisItemsFound > 0 {
                            Text("\(downloadManager.analysisItemsFound) Titel gefunden")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }

                    Text(downloadManager.analysisStatusText.isEmpty ? "Verbinde mit Webseite & rufe Inhaltsstruktur ab..." : downloadManager.analysisStatusText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Cancel Button
                Button(action: {
                    downloadManager.cancelAnalysis()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Abbrechen")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(6)
                    .shadow(color: Color.red.opacity(0.35), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .help("Playlist-Analyse sofort abbrechen (Esc)")
            }

            // Live Linear Progress Bar
            HStack(spacing: 10) {
                ProgressView(value: downloadManager.analysisProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text("\(Int(downloadManager.analysisProgress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.19), Color(red: 0.08, green: 0.10, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.blue.opacity(0.35)),
            alignment: .bottom
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: downloadManager.isAnalyzingURL)
    }

    // MARK: - Queue Control Strip
    private var queueControlStrip: some View {
        Group {
            if !downloadManager.selectedItemIds.isEmpty {
                // Batch Selection Bar (Requirement 5)
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("\(downloadManager.selectedItemIds.count) von \(downloadManager.queue.count) markiert")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Starten / Fortsetzen
                    Button(action: { downloadManager.resumeSelected() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Starten")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Pausieren
                    Button(action: { downloadManager.pauseSelected() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 10))
                            Text("Pausieren")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.yellow)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Überspringen
                    Button(action: { downloadManager.skipSelected() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 10))
                            Text("Überspringen")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Als Liste speichern
                    Button(action: { downloadManager.exportSelectedOrAllList() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 10))
                            Text("Liste speichern...")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Ausgewählte Einträge als .mvl Datei speichern")

                    // Rename Button for selected items
                    let selectedCompleted = downloadManager.queue.filter { downloadManager.selectedItemIds.contains($0.id) && $0.status.isCompleted }
                    if !selectedCompleted.isEmpty {
                        Button(action: { downloadManager.openRenameStudio(items: selectedCompleted) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Umbenennen (\(selectedCompleted.count))...")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.25))
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.blue.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Ausgewählte fertige Downloads im Rename Studio umbenennen")
                    }

                    // Entfernen
                    Button(action: { downloadManager.removeSelected() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Entfernen")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.18))
                        .foregroundColor(.red)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    // Abwählen
                    Button(action: { downloadManager.deselectAll() }) {
                        Text("Auswahl aufheben")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color(red: 0.12, green: 0.14, blue: 0.20))
            } else {
                // Standard Queue Toolbar
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text("\(downloadManager.queue.count) in Warteschlange")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)

                        if downloadManager.activeCount > 0 {
                            Text("(\(downloadManager.activeCount) aktiv)")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }

                        let failedCount = downloadManager.queue.filter { $0.status.isFailed }.count
                        if failedCount > 0 {
                            Text("(\(failedCount) mit Fehler)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }

                    if !downloadManager.queue.isEmpty {
                        Button(action: { downloadManager.selectAll() }) {
                            Text("Alle markieren")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Download-Liste Aktionen (.mvl) (Requirement 6)
                    Button(action: { downloadManager.importListFromPanel() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10))
                            Text("Liste öffnen...")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Gespeicherte Download-Liste (.mvl) öffnen und Warteschlange füllen")

                    if !downloadManager.queue.isEmpty {
                        Button(action: { downloadManager.exportSelectedOrAllList() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 10))
                                Text("Liste speichern...")
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Downloads als wiederverwendbare .mvl Datei sichern")
                    }

                    // Rename Studio Button if any completed items exist
                    let completedItems = downloadManager.queue.filter { $0.status.isCompleted }
                    if !completedItems.isEmpty {
                        Button(action: { downloadManager.openRenameStudio(items: completedItems) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Rename Studio (\(completedItems.count))")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.blue.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Fertige Downloads im Rename Studio in Serien- oder Staffelstruktur umbenennen")
                    }

                    // Pause / Resume All (Requirement 2)
                    if downloadManager.isPaused {
                        Button(action: { downloadManager.resumeAll() }) {
                            Label("Alle fortsetzen", systemImage: "play.fill")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(5)
                    } else if downloadManager.activeCount > 0 || downloadManager.queue.contains(where: { $0.status == .queued }) {
                        Button(action: { downloadManager.pauseAll() }) {
                            Label("Alle pausieren", systemImage: "pause.fill")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(5)
                    }

                    // Clear Completed
                    Button(action: { downloadManager.clearCompleted() }) {
                        Text("Fertige aufräumen")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(downloadManager.queue.allSatisfy { !$0.status.isTerminal })

                    // Clear All
                    Button(action: { downloadManager.clearAll() }) {
                        Text("Alle leeren")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(downloadManager.queue.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.10, green: 0.10, blue: 0.12))
            }
        }
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.06)),
            alignment: .bottom
        )
    }

    // MARK: - Bottom Statusbar
    private var bottomStatusBar: some View {
        HStack(spacing: 12) {
            if downloadManager.activeCount > 0 {
                ProgressView(value: downloadManager.overallProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 140)

                Text("\(Int(downloadManager.overallProgress * 100))% Gesamtladefortschritt")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                Text("Bereit")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Ziel: \(settings.downloadFolder.path)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(red: 0.09, green: 0.09, blue: 0.11))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.06)),
            alignment: .top
        )
    }

    // MARK: - Post-Download Rename Studio Banner
    private func postDownloadRenameBanner(for item: DownloadItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Download abgeschlossen:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }

                Text("Möchtest du diese Datei jetzt im Rename Studio in Serien- oder Staffelstruktur umbenennen?")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    downloadManager.renamePromptItem = nil
                    downloadManager.openRenameStudio(items: [item])
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Jetzt umbenennen")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button("Später") {
                    withAnimation {
                        downloadManager.renamePromptItem = nil
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Button(action: {
                    settings.askToRenameAfterDownload = false
                    withAnimation {
                        downloadManager.renamePromptItem = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Nicht mehr automatisch nachfragen")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.11, green: 0.14, blue: 0.22))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.blue.opacity(0.35)),
            alignment: .bottom
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Drag & Drop Handler (supports URLs, text, and .mvl list files)
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    let targetURL: URL?
                    if let u = item as? URL {
                        targetURL = u
                    } else if let data = item as? Data, let str = String(data: data, encoding: .utf8), let u = URL(string: str) {
                        targetURL = u
                    } else {
                        targetURL = nil
                    }

                    if let fileURL = targetURL {
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
                            DispatchQueue.main.async {
                                downloadManager.openRenameStudioForFolder(fileURL)
                            }
                            return
                        }

                        let ext = fileURL.pathExtension.lowercased()
                        if ext == "mvl" || ext == "json" {
                            DispatchQueue.main.async {
                                _ = downloadManager.importList(from: fileURL)
                            }
                        }
                    }
                }
            } else {
                provider.loadItem(forTypeIdentifier: "public.utf8-plain-text", options: nil) { item, _ in
                    if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            downloadManager.analyzeOrAddURL(text, downloadType: .video, videoQuality: .best, audioFormat: .mp3)
                        }
                    } else if let string = item as? String {
                        DispatchQueue.main.async {
                            downloadManager.analyzeOrAddURL(string, downloadType: .video, videoQuality: .best, audioFormat: .mp3)
                        }
                    }
                }
            }
        }
        return true
    }

    private func openStandaloneFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Ordner öffnen"
        panel.message = "Wähle einen Ordner aus, um alle enthaltenen Dateien rekursiv umzubenennen."
        if panel.runModal() == .OK, let url = panel.url {
            downloadManager.openRenameStudioForFolder(url)
        }
    }
}
