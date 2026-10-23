import SwiftUI
import AppKit

public struct FileBotRenameSheet: View {
    @ObservedObject var downloadManager: DownloadManager
    @StateObject private var settings = AppSettings.shared

    @State private var renameItems: [FileBotRenameItem] = []
    @State private var mode: FileBotProcessingMode = .series
    @State private var database: FileBotDatabase = .themoviedb
    @State private var language: FileBotLanguage = .german
    @State private var formatExpression: String = "{n} - {s00e00} - {t}"
    @State private var seriesQuery: String = ""
    @State private var isMatching: Bool = false
    @State private var isRenaming: Bool = false
    @State private var statusText: String = "Bereit. Passe die Einstellungen oder den KI-Prompt an und klicke auf 'Abgleichen'."
    @State private var renameCompletedCount: Int? = nil
    @State private var tempGeminiApiKey: String = ""
    @State private var showApiKeySection: Bool = false

    // AI Prompt & Custom Markup/Filter Support
    @State private var aiPromptText: String = ""
    @State private var currentFolder: URL
    @State private var categoryFilter: FileCategoryFilter = .all
    @State private var searchQuery: String = ""
    @State private var useCustomGeminiAI: Bool = false
    @State private var isDropTargeted: Bool = false

    private let sourceItems: [DownloadItem]?
    private let service = FileBotService.shared

    public init(
        downloadManager: DownloadManager,
        items: [DownloadItem]? = nil,
        standaloneFolder: URL? = nil
    ) {
        self.downloadManager = downloadManager
        self.sourceItems = items
        let initialFolder = standaloneFolder
            ?? items?.first?.destinationFolder
            ?? AppSettings.shared.downloadFolder
        _currentFolder = State(initialValue: initialFolder)
    }

    private var isGeminiActive: Bool {
        return (mode == .custom && useCustomGeminiAI) || (mode != .custom && database == .gemini)
    }

    public var filteredItems: [FileBotRenameItem] {
        renameItems.filter { item in
            let matchesCategory = categoryFilter.matches(url: item.originalURL)
            let matchesSearch = searchQuery.isEmpty ||
                item.originalName.localizedCaseInsensitiveContains(searchQuery) ||
                item.proposedRelativePath.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesSearch
        }
    }

    public var selectedFilteredCount: Int {
        filteredItems.filter(\.isSelected).count
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            // Configuration Controls
            configurationStrip

            if isGeminiActive && (!settings.hasGeminiApiKey || showApiKeySection) {
                geminiApiKeyBanner
            }

            // Category & Search Filter Strip
            filterAndSelectionStrip

            Divider()
                .background(Color.white.opacity(0.1))

            // Dual-Pane FileBot Table
            dualPaneComparisonView

            Divider()
                .background(Color.white.opacity(0.1))

            // Footer Status & Actions
            footerBar
        }
        .frame(minWidth: 980, idealWidth: 1040, minHeight: 640, idealHeight: 700)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        .preferredColorScheme(.dark)
        .onAppear {
            initializeItems()
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.55, blue: 0.95), Color(red: 0.10, green: 0.35, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("FileBot Rename Studio")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    if service.isAvailable(), let ver = service.getVersion() {
                        Text(ver)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else {
                        Text("Lokale Heuristik & KI")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }

                Text("Serien, Filme & beliebige Dateien rekursiv nach Schema oder KI umbenennen")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Active Folder Badge & Open Folder Button
            Button(action: openFolderPicker) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ordner:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(currentFolder.lastPathComponent)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Anderen Ordner auswählen & rekursiv einlesen (inkl. aller Unterordner)")

            Button(action: {
                downloadManager.fileBotRenameItems = nil
                downloadManager.fileBotStandaloneFolder = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.13, green: 0.13, blue: 0.15))
    }

    // MARK: - Configuration Strip
    private var configurationStrip: some View {
        VStack(spacing: 8) {
            // Row 1: Mode Switcher & Engine Selection
            HStack(spacing: 12) {
                // Processing Mode
                VStack(alignment: .leading, spacing: 3) {
                    Text("Verarbeitungsmodus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $mode) {
                        ForEach(FileBotProcessingMode.allCases) { m in
                            Label(m.displayName, systemImage: m.icon).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)
                    .onChange(of: mode) { newMode in
                        formatExpression = newMode.defaultFormat
                        if newMode == .custom && database == .gemini {
                            useCustomGeminiAI = true
                        }
                    }
                }

                if mode == .custom {
                    // Method for custom files: Markup Tokens vs Gemini AI
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Methode")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $useCustomGeminiAI) {
                            Text("Markup & Tokens").tag(false)
                            Text("✨ Google Gemini KI").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                        .onChange(of: useCustomGeminiAI) { isAI in
                            if isAI && !settings.hasGeminiApiKey {
                                showApiKeySection = true
                            }
                        }
                    }

                    if useCustomGeminiAI {
                        // Gemini Model Picker
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Gemini KI-Modell")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.purple)

                            Picker("", selection: $settings.geminiModel) {
                                ForEach(GeminiModelOption.availableModels) { opt in
                                    Text(opt.displayName).tag(opt.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 170)
                        }
                    }
                } else {
                    // Series Title Query
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Serientitel / Suchbegriff (TMDb / TVDB)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))

                            TextField("z. B. Breaking Bad oder Babylon Berlin", text: $seriesQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .onSubmit {
                                    triggerMatch()
                                }

                            if !seriesQuery.isEmpty {
                                Button(action: {
                                    seriesQuery = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }

                    // Database Engine
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Engine / Abgleich")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $database) {
                            ForEach(FileBotDatabase.allCases) { db in
                                Text(db.displayName).tag(db)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 190)
                        .onChange(of: database) { newDb in
                            if newDb == .gemini && !settings.hasGeminiApiKey {
                                showApiKeySection = true
                            }
                        }
                    }

                    if database == .gemini {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Gemini KI-Modell")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.purple)

                            Picker("", selection: $settings.geminiModel) {
                                ForEach(GeminiModelOption.availableModels) { opt in
                                    Text(opt.displayName).tag(opt.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 160)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sprache")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            Picker("", selection: $language) {
                                ForEach(FileBotLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 110)
                        }
                    }
                }

                Spacer()
            }

            // Row 2: AI Prompt Input (Visible whenever Gemini is active!)
            if isGeminiActive {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 12, weight: .bold))

                    Text("KI-Prompt & Hinweise:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)

                    TextField(
                        mode == .custom
                            ? "z. B. 'Rechnungen nach Datum und Firma umbenennen' oder 'Fotos nummerieren'..."
                            : "z. B. 'Staffel 2, echte TVDB-Reihenfolge nach Episodentitel prüfen', 'Chronologisch ab Folge 1 nummerieren'...",
                        text: $aiPromptText
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.purple.opacity(0.35), lineWidth: 1))
                    .onSubmit {
                        triggerMatch()
                    }

                    // Prompt Ideas Menu
                    Menu {
                        Text("Vorgaben & Hinweise für KI:")
                        if mode == .custom {
                            Button("📄 Rechnungen (YYYY-MM-DD_Firma_Rechnung)") {
                                aiPromptText = "Benenne Rechnungsdokumente nach dem Schema 'YYYY-MM-DD - [Firma oder Aussteller] - Rechnung.pdf' um."
                            }
                            Button("🖼️ Fotos (Datum & Motiv)") {
                                aiPromptText = "Erkenne Aufnahmedatum und Motiv und erstelle sprechende Bildnamen (z. B. '2024-06-15 - Strand.jpg')."
                            }
                            Button("🧹 Bereinigen & Lesbar machen") {
                                aiPromptText = "Entferne Web-Artefakte, Kanalnamen, kryptische Zeichen, doppelte Leerzeichen und Videoauflösungen."
                            }
                            Button("📂 Nach Jahr in Ordner strukturieren") {
                                aiPromptText = "Sortiere Dateien in Jahresordner ein: '[YYYY]/[YYYY-MM-DD] - [Dateiname].[ext]'."
                            }
                        } else {
                            Button("🔍 Echte TVDB/TMDb Episodennummerierung ermitteln") {
                                aiPromptText = "Recherchiere die echten Episodennummern passend zu den Episodentiteln. Ein alphabetisch früher Buchstabe ist nicht Folge 1."
                            }
                            Button("🔢 Chronologisch / Fortlaufend nummerieren (1...N)") {
                                aiPromptText = "Staffel 1. Nummeriere die Episoden fortlaufend ab Folge 1 (s01e01, s01e02, s01e03...)."
                            }
                            Button("📺 Staffel 2 vorgeben (s02e01...)") {
                                aiPromptText = "Dies ist Staffel 2. Nummeriere als s02e01, s02e02 fortlaufend nach dem tatsächlichen Episodeninhalt."
                            }
                            Button("🧹 Mediathek- & Sendernamen entfernen") {
                                aiPromptText = "Bereinige Sendernamen (ARD, ZDF), Kürzel und Auflösungen vollständig aus dem Episodentitel."
                            }
                        }
                        Divider()
                        Button("Textfeld leeren") {
                            aiPromptText = ""
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "lightbulb.fill")
                            Text("Tipps")
                        }
                        .font(.system(size: 11))
                    }
                    .frame(width: 75)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.10))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.purple.opacity(0.25), lineWidth: 1))
            }

            // Row 3: Format Expression, Token Chips & Match Button
            HStack(spacing: 10) {
                Text("Format-Ausdruck:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("Format-Expression...", text: $formatExpression)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .onSubmit {
                        triggerMatch()
                    }

                // Presets Menu
                Menu {
                    Text("Muster-Vorlagen:")
                    if mode == .series {
                        ForEach(FileBotFormatPreset.seriesPresets) { preset in
                            Button("\(preset.name) (\(preset.format))") {
                                formatExpression = preset.format
                            }
                        }
                    } else if mode == .season {
                        ForEach(FileBotFormatPreset.seasonPresets) { preset in
                            Button("\(preset.name) (\(preset.format))") {
                                formatExpression = preset.format
                            }
                        }
                    } else {
                        ForEach(FileBotFormatPreset.customPresets) { preset in
                            Button("\(preset.name) (\(preset.format))") {
                                formatExpression = preset.format
                            }
                        }
                    }
                    Divider()
                    Button("Standard wiederherstellen") {
                        formatExpression = mode.defaultFormat
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Vorlagen")
                    }
                    .font(.system(size: 11))
                }
                .frame(width: 95)

                if mode != .custom && database != .gemini {
                    Button(action: {
                        database = .gemini
                        if !settings.hasGeminiApiKey {
                            showApiKeySection = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Plex KI")
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }

                // Prominent Match Button (THE ONLY TRIGGER)
                Button(action: triggerMatch) {
                    HStack(spacing: 6) {
                        if isMatching {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: isGeminiActive ? "sparkles" : "arrow.clockwise")
                        }
                        Text(isGeminiActive ? "Mit KI abgleichen" : "Abgleichen")
                    }
                    .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(isGeminiActive ? .purple : .blue)
                .disabled(isMatching)
            }

            // Row 3b: Token Chips for Custom Mode (Markup)
            if mode == .custom && !useCustomGeminiAI {
                HStack(spacing: 6) {
                    Text("Markup-Tokens:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    tokenChip("{original}", tooltip: "Original-Dateiname ohne Endung")
                    tokenChip("{folder}", tooltip: "Name des übergeordneten Ordners")
                    tokenChip("{date}", tooltip: "Dateidatum im Format YYYY-MM-DD")
                    tokenChip("{index.pad(2)}", tooltip: "Fortlaufende Nummerierung 01, 02...")
                    tokenChip("{clean}", tooltip: "Name bereinigt von Sonderzeichen & Punkten")
                    tokenChip("{lower}", tooltip: "In Kleinbuchstaben umwandeln")
                    tokenChip("{ext}", tooltip: "Original Dateiendung")

                    Spacer()
                }
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }

    private func tokenChip(_ token: String, tooltip: String) -> some View {
        Button(action: {
            if formatExpression.isEmpty {
                formatExpression = token
            } else {
                formatExpression += " - \(token)"
            }
        }) {
            Text("+ \(token)")
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.cyan)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Filter & Selection Strip
    private var filterAndSelectionStrip: some View {
        HStack(spacing: 12) {
            // Category Filter Pills
            HStack(spacing: 4) {
                ForEach(FileCategoryFilter.allCases) { cat in
                    let count = renameItems.filter { cat.matches(url: $0.originalURL) }.count
                    Button(action: {
                        categoryFilter = cat
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 10))
                            Text(cat.displayName)
                            Text("(\(count))")
                                .font(.system(size: 9, design: .monospaced))
                                .opacity(0.7)
                        }
                        .font(.system(size: 11, weight: categoryFilter == cat ? .bold : .regular))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryFilter == cat ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                        .foregroundColor(categoryFilter == cat ? .white : .secondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(categoryFilter == cat ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Search Box
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))

                TextField("Dateien filtern...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .frame(width: 140)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.3))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))

            // Selection Quick Actions
            HStack(spacing: 6) {
                Button("Alle") {
                    for item in filteredItems {
                        item.isSelected = true
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.blue)

                Text("•")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))

                Button("Keine") {
                    for item in filteredItems {
                        item.isSelected = false
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

                Text("(\(selectedFilteredCount)/\(filteredItems.count))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
    }

    // MARK: - Gemini API Key Inline Banner
    private var geminiApiKeyBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 30, height: 30)
                Image(systemName: "key.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 12, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Google Gemini API-Key eingeben")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text("Wird sicher im macOS-Schlüsselbund gespeichert. Kostenlos bei aistudio.google.com erhältlich.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            SecureField("Gemini API-Key einfügen...", text: $tempGeminiApiKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .frame(width: 200)

            Button("Speichern & Abgleichen") {
                settings.setGeminiApiKey(tempGeminiApiKey)
                showApiKeySection = false
                tempGeminiApiKey = ""
                triggerMatch()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .font(.system(size: 11, weight: .semibold))
            .disabled(tempGeminiApiKey.trimmingCharacters(in: .whitespaces).isEmpty)

            if settings.hasGeminiApiKey {
                Button("Ausblenden") {
                    showApiKeySection = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.12))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Dual-Pane Comparison View (FileBot Style)
    private var dualPaneComparisonView: some View {
        VStack(spacing: 0) {
            // Column Headers
            HStack(spacing: 0) {
                // Left Column Header
                HStack(spacing: 6) {
                    Toggle("", isOn: Binding(
                        get: { !filteredItems.isEmpty && filteredItems.allSatisfy(\.isSelected) },
                        set: { checked in
                            for item in filteredItems { item.isSelected = checked }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)

                    Image(systemName: "doc.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    Text("Originaldateien (\(filteredItems.count))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)

                // Match Arrow Header
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 36)

                // Right Column Header
                HStack {
                    Image(systemName: mode == .season ? "folder.fill.badge.gearshape" : "doc.badge.gearshape.fill")
                        .foregroundColor(Color.green.opacity(0.85))
                        .font(.system(size: 11))
                    Text("Neue Dateinamen & Struktur (Vorschau)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Klickbar zum manuellen Anpassen")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 7)
            .background(Color(red: 0.14, green: 0.14, blue: 0.16))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.08)), alignment: .bottom)

            // Rows List
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(renameItems.isEmpty ? "Keine Dateien im ausgewählten Ordner gefunden" : "Keine Dateien entsprechen dem Filter")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Button("Ordner auswählen...") {
                        openFolderPicker()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredItems) { item in
                            FileBotRowView(item: item)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack(spacing: 12) {
            // Status Info
            HStack(spacing: 6) {
                if isRenaming {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                }

                if let count = renameCompletedCount {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(count) Dateien erfolgreich umbenannt!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    Text(statusText.isEmpty ? "\(selectedFilteredCount) von \(renameItems.count) Dateien zum Umbenennen ausgewählt" : statusText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Anderen Ordner öffnen...") {
                openFolderPicker()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.blue)

            Button("Abbrechen") {
                downloadManager.fileBotRenameItems = nil
                downloadManager.fileBotStandaloneFolder = nil
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.secondary)

            Button(action: executeRename) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text(renameCompletedCount != nil ? "Schließen" : "Umbenennen ausführen (\(selectedFilteredCount) Dateien)")
                }
                .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(renameCompletedCount != nil ? .green : .red)
            .disabled(selectedFilteredCount == 0 || isMatching || isRenaming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }

    // MARK: - Actions

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Ordner einlesen"
        panel.message = "Wähle einen Ordner aus. Alle darin enthaltenen Dateien und Unterordner werden rekursiv eingelesen."

        if panel.runModal() == .OK, let folderURL = panel.url {
            loadFolder(folderURL)
        }
    }

    private func loadFolder(_ folderURL: URL) {
        currentFolder = folderURL
        renameCompletedCount = nil
        let scanned = service.scanFolderRecursively(folderURL: folderURL)
        self.renameItems = scanned
        self.statusText = "\(scanned.count) Dateien aus '\(folderURL.lastPathComponent)' eingelesen. Klicke auf 'Abgleichen', um die Vorschau zu erstellen."
    }

    private func initializeItems() {
        if let sources = sourceItems, !sources.isEmpty {
            var items: [FileBotRenameItem] = []
            var detectedSeries: String? = nil

            for src in sources {
                let fileURL = src.completedFileURL ?? src.destinationFolder.appendingPathComponent(src.title)
                let rItem = FileBotRenameItem(
                    downloadItemId: src.id,
                    originalURL: fileURL,
                    originalName: fileURL.lastPathComponent,
                    targetFolder: src.destinationFolder,
                    seasonNumber: src.seasonNumber,
                    episodeNumber: src.episodeNumber,
                    seriesName: src.seriesTitle,
                    isSelected: true
                )
                items.append(rItem)

                if detectedSeries == nil, let s = src.seriesTitle, !s.isEmpty {
                    detectedSeries = s
                }
            }

            self.renameItems = items
            if let s = detectedSeries {
                self.seriesQuery = s
            }
            self.formatExpression = mode.defaultFormat
            self.statusText = "\(items.count) Dateien bereit. Passe Einstellungen oder KI-Prompt an und klicke auf 'Abgleichen'."
        } else if let standalone = downloadManager.fileBotStandaloneFolder {
            loadFolder(standalone)
        } else {
            loadFolder(currentFolder)
        }
    }

    private func triggerMatch() {
        guard !renameItems.isEmpty else { return }
        isMatching = true

        let currentMode = mode
        let effectiveDb: FileBotDatabase = (currentMode == .custom && useCustomGeminiAI) ? .gemini : database
        let currentLang = language
        let currentFormat = formatExpression
        let currentQuery = seriesQuery
        let currentOutput = currentFolder
        let currentInstruction = aiPromptText

        statusText = isGeminiActive ? "Frage Google Gemini KI ab..." : "Gleiche Dateinamen ab..."

        Task {
            do {
                try await service.matchFiles(
                    items: renameItems,
                    mode: currentMode,
                    database: effectiveDb,
                    language: currentLang,
                    format: currentFormat,
                    seriesQuery: currentQuery,
                    outputFolder: currentOutput,
                    customInstruction: currentInstruction
                )
                await MainActor.run {
                    self.isMatching = false
                    self.statusText = "Vorschau aktualisiert (\(renameItems.count) Dateien zugeordnet)."
                }
            } catch {
                await MainActor.run {
                    self.isMatching = false
                    self.statusText = "Fehler beim Abgleich: \(error.localizedDescription)"
                }
            }
        }
    }

    private func executeRename() {
        if renameCompletedCount != nil {
            downloadManager.fileBotRenameItems = nil
            downloadManager.fileBotStandaloneFolder = nil
            return
        }

        isRenaming = true
        statusText = "Benenne Dateien um..."

        Task {
            do {
                let success = try await service.performRename(
                    items: renameItems,
                    onItemRenamed: { downloadId, newURL, newTitle in
                        Task { @MainActor in
                            downloadManager.updateItemAfterRename(
                                itemId: downloadId,
                                newURL: newURL,
                                newTitle: newTitle
                            )
                        }
                    }
                )

                await MainActor.run {
                    self.isRenaming = false
                    self.renameCompletedCount = success
                    self.statusText = "Erfolgreich \(success) Dateien umbenannt!"
                }
            } catch {
                await MainActor.run {
                    self.isRenaming = false
                    self.statusText = "Fehler beim Umbenennen: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                let targetURL: URL?
                if let u = item as? URL {
                    targetURL = u
                } else if let data = item as? Data, let str = String(data: data, encoding: .utf8), let u = URL(string: str) {
                    targetURL = u
                } else {
                    targetURL = nil
                }

                if let url = targetURL {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        DispatchQueue.main.async {
                            loadFolder(url)
                        }
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Dedicated Observable Row View for FileBot
private struct FileBotRowView: View {
    @ObservedObject var item: FileBotRenameItem

    var body: some View {
        HStack(spacing: 0) {
            // Selection Checkbox
            Toggle("", isOn: $item.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .padding(.leading, 8)

            // Left: Original File
            HStack(spacing: 8) {
                fileIcon(for: item.originalURL)
                    .font(.system(size: 13))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.originalName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(item.isSelected ? .white : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        if let rel = item.relativeSourcePath, rel.contains("/") {
                            let parent = (rel as NSString).deletingLastPathComponent
                            Text("📁 \(parent)")
                                .font(.system(size: 9))
                                .foregroundColor(.cyan.opacity(0.8))
                        }

                        Text(item.originalURL.deletingLastPathComponent().path)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)

            // Center: Arrow
            ZStack {
                Circle()
                    .fill(item.isRenamed ? Color.green.opacity(0.2) : (item.isMatched ? Color.blue.opacity(0.2) : Color.white.opacity(0.06)))
                    .frame(width: 22, height: 22)

                Image(systemName: item.isRenamed ? "checkmark" : "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(item.isRenamed ? .green : (item.isMatched ? .blue : .secondary))
            }
            .frame(width: 36)

            // Right: Proposed New Name / Structure (Editable)
            HStack(spacing: 8) {
                Image(systemName: item.isFolderChange ? "folder.fill" : "checkmark.seal.fill")
                    .foregroundColor(item.isRenamed ? .green : Color.blue.opacity(0.85))
                    .font(.system(size: 13))

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Neuer Name...", text: $item.proposedRelativePath)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(item.isRenamed ? .green : (item.isSelected ? .white : .secondary))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if item.isFolderChange, let sub = item.destinationSubfolderName {
                            Text("📁 \(sub)")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundColor(.yellow)
                                .cornerRadius(3)
                        }

                        Text(item.statusMessage)
                            .font(.system(size: 9))
                            .foregroundColor(item.isError ? .red : (item.isRenamed ? .green : .secondary))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(item.isRenamed ? Color.green.opacity(0.05) : Color.black.opacity(0.2))
            .cornerRadius(6)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 2)
        .background(item.isSelected ? Color.white.opacity(0.02) : Color.black.opacity(0.15))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(item.isRenamed ? Color.green.opacity(0.3) : (item.isMatched ? Color.blue.opacity(0.2) : Color.white.opacity(0.04)), lineWidth: 1)
        )
        .opacity(item.isSelected ? 1.0 : 0.45)
    }

    @ViewBuilder
    private func fileIcon(for url: URL) -> some View {
        let ext = url.pathExtension.lowercased()
        if ["mp4", "mkv", "mov", "avi", "webm", "m4v"].contains(ext) {
            Image(systemName: "film.fill").foregroundColor(.purple)
        } else if ["mp3", "m4a", "flac", "wav", "aac", "ogg"].contains(ext) {
            Image(systemName: "music.note").foregroundColor(.pink)
        } else if ["pdf", "doc", "docx", "txt", "rtf", "odt", "xls", "xlsx"].contains(ext) {
            Image(systemName: "doc.text.fill").foregroundColor(.orange)
        } else if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext) {
            Image(systemName: "photo.fill").foregroundColor(.teal)
        } else {
            Image(systemName: "doc.fill").foregroundColor(.secondary)
        }
    }
}
