import SwiftUI
import AppKit

public struct SettingsSheet: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var installationService = AppInstallationService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var toolStatus: ToolStatus = SystemService.shared.checkToolsStatus()
    @State private var selectedTab: Int = 0
    @State private var installStatusMessage: String? = nil
    @State private var showConfirmUninstall: Bool = false
    @State private var isTestingCookies: Bool = false
    @State private var cookieTestResult: (success: Bool, message: String)? = nil
    @State private var currentApiKeyInput: String = ""
    @State private var isApiKeyVisible: Bool = false
    @State private var isTestingAI: Bool = false
    @State private var aiTestResult: (success: Bool, message: String)? = nil
    @State private var isRefreshingModels: Bool = false
    @State private var refreshStatusMessage: String? = nil

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
                Text("Einstellungen")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(red: 0.13, green: 0.13, blue: 0.15))

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Allgemein").tag(0)
                Text("KI-Anbieter").tag(1)
                Text("Account & Cookies").tag(2)
                Text("Werkzeuge & Diagnose").tag(3)
                Text("Changelog").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == 0 {
                        generalTab
                    } else if selectedTab == 1 {
                        aiTab
                    } else if selectedTab == 2 {
                        accountTab
                    } else if selectedTab == 3 {
                        toolsTab
                    } else {
                        changelogTab
                    }
                }
                .padding()
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Footer
            HStack {
                Text("Mac Video Loader v0.6.0 (MVL)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Button("Fertig") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
            .background(Color(red: 0.13, green: 0.13, blue: 0.15))
        }
        .frame(width: 580, height: 500)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        .onAppear {
            refreshTools()
            currentApiKeyInput = settings.getApiKey(for: settings.selectedAIProvider)
        }
    }

    // MARK: - Tab 1: Allgemein
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Download-Zielordner")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.yellow)
                    Text(settings.downloadFolder.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()

                    Button("Im Finder öffnen") {
                        NSWorkspace.shared.open(settings.downloadFolder)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(5)

                    Button("Auswählen...") {
                        chooseFolder()
                    }
                    .font(.system(size: 11))
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Gleichzeitige Downloads")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                HStack {
                    Text("Maximale parallele Downloads:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Stepper("\(settings.maxConcurrentDownloads)", value: $settings.maxConcurrentDownloads, in: 1...6)
                        .frame(width: 100)
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            // Rename Studio Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Rename Studio & Medien-Organisation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $settings.askToRenameAfterDownload) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unmittelbar nach dem Download nach Umbenennen fragen")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Text("Fragt bei fertiggestellten Downloads, ob sie im Rename Studio in Serien- oder Staffelstruktur gebracht werden sollen.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            // Installation Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Installation & Programme-Ordner")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: installationService.isInstalled ? "checkmark.seal.fill" : "arrow.down.app")
                            .foregroundColor(installationService.isInstalled ? .green : .orange)
                            .font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(installationService.isInstalled ? "In /Applications installiert" : "Nicht im Programme-Ordner")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Text(installationService.isRunningFromApplications ? "Die App läuft aktuell aus /Applications." : "Die App läuft aktuell aus dem Projektverzeichnis.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if installationService.isInstalled {
                            Button("Im Finder anzeigen") {
                                NSWorkspace.shared.activateFileViewerSelecting([installationService.applicationsAppURL])
                            }
                            .font(.system(size: 11))

                            Button("Deinstallieren...") {
                                showConfirmUninstall = true
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        } else {
                            Button("In /Applications installieren") {
                                performInstall()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .font(.system(size: 11, weight: .semibold))
                        }
                    }

                    if let msg = installStatusMessage {
                        Text(msg)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .alert("Mac Video Loader wirklich deinstallieren?", isPresented: $showConfirmUninstall) {
                Button("Abbrechen", role: .cancel) {}
                Button("Deinstallieren", role: .destructive) {
                    performUninstall()
                }
            } message: {
                Text("Die Anwendung wird aus /Applications gelöscht.")
            }

            // Lizenz & Urheberrecht Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Lizenz & Urheberrecht")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "c.circle")
                            .foregroundColor(.accentColor)
                        Text("Creative Commons Namensnennung - Nicht-kommerziell 4.0 (CC BY-NC 4.0)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text("Dieses Projekt darf unter Nennung des Autors (mrgoldsmitt) frei geteilt und verbreitet werden. Eine kommerzielle Nutzung ist ausgeschlossen.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }

    // MARK: - Tab: KI-Anbieter & Modelle (ChatGPT, Claude, Gemini)
    private var aiTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Card
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.5, green: 0.2, blue: 0.9), Color(red: 0.2, green: 0.4, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("KI-Anbindung (ChatGPT, Claude & Gemini)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Wähle deinen bevorzugten KI-Anbieter und hinterlege deinen API-Key sicher im macOS-Schlüsselbund.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Provider Switcher
            VStack(alignment: .leading, spacing: 8) {
                Text("Bevorzugter KI-Anbieter")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Picker("", selection: $settings.selectedAIProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.selectedAIProvider) { newProvider in
                    currentApiKeyInput = settings.getApiKey(for: newProvider)
                    aiTestResult = nil
                    refreshStatusMessage = nil
                    isApiKeyVisible = false
                    if settings.hasApiKey(for: newProvider) && settings.dynamicModels[newProvider.rawValue] == nil {
                        Task {
                            isRefreshingModels = true
                            _ = await settings.refreshModels(for: newProvider)
                            isRefreshingModels = false
                        }
                    }
                }
            }

            // Section 1: API Key & Keychain for Selected Provider
            let currentProvider = settings.selectedAIProvider
            let hasKey = settings.hasApiKey(for: currentProvider)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: currentProvider.icon)
                            .foregroundColor(.purple)
                        Text("\(currentProvider.displayName) API-Key")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if hasKey {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Im Schlüsselbund gesichert")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Nicht konfiguriert")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if isApiKeyVisible {
                            TextField(keyPlaceholder(for: currentProvider), text: $currentApiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        } else {
                            SecureField(keyPlaceholder(for: currentProvider), text: $currentApiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }

                        Button(action: { isApiKeyVisible.toggle() }) {
                            Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help(isApiKeyVisible ? "Schlüssel maskieren" : "Schlüssel anzeigen")

                        Button("Speichern") {
                            settings.setApiKey(currentApiKeyInput, for: currentProvider)
                            aiTestResult = (true, "\(currentProvider.shortName) API-Key sicher im macOS-Schlüsselbund gespeichert.")
                            Task {
                                isRefreshingModels = true
                                let res = await settings.refreshModels(for: currentProvider)
                                isRefreshingModels = false
                                refreshStatusMessage = res.message
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .font(.system(size: 11, weight: .semibold))
                        .disabled(currentApiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                        if hasKey {
                            Button("Löschen") {
                                settings.deleteApiKey(for: currentProvider)
                                currentApiKeyInput = ""
                                aiTestResult = nil
                                refreshStatusMessage = nil
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        }
                    }

                    // Key Test Button & Link
                    HStack(spacing: 10) {
                        Button(action: testCurrentApiKey) {
                            if isTestingAI {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle")
                                    Text("Verbindung zu \(currentProvider.shortName) (\(settings.getModel(for: currentProvider))) testen")
                                }
                                .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingAI || currentApiKeyInput.isEmpty)

                        Button(action: {
                            NSWorkspace.shared.open(currentProvider.portalURL)
                        }) {
                            HStack(spacing: 3) {
                                Text("API-Key bei \(currentProvider.portalDisplayName) holen")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    if let result = aiTestResult {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(result.success ? .green : .orange)
                                .font(.system(size: 12))
                            Text(result.message)
                                .font(.system(size: 11))
                                .foregroundColor(result.success ? .green : .orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background((result.success ? Color.green : Color.orange).opacity(0.12))
                        .cornerRadius(6)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            // Section 2: Model Selection
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Modell für \(currentProvider.displayName)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        Task {
                            isRefreshingModels = true
                            refreshStatusMessage = nil
                            let res = await settings.refreshModels(for: currentProvider)
                            isRefreshingModels = false
                            refreshStatusMessage = res.message
                        }
                    }) {
                        if isRefreshingModels {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Modelle abrufen")
                            }
                            .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshingModels || !hasKey)
                    .help("Verfügbare Modelle live von \(currentProvider.displayName) über deinen API-Key abfragen")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Picker("Modell:", selection: Binding(
                            get: { settings.getModel(for: currentProvider) },
                            set: { settings.setModel($0, for: currentProvider) }
                        )) {
                            ForEach(settings.models(for: currentProvider)) { opt in
                                Text("\(opt.displayName)\(opt.isRecommended ? " (Empfohlen)" : "")").tag(opt.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 12))
                        .onChange(of: settings.getModel(for: currentProvider)) { _ in
                            aiTestResult = nil
                        }

                        Spacer()
                    }

                    if let selected = settings.models(for: currentProvider).first(where: { $0.id == settings.getModel(for: currentProvider) }) {
                        Text(selected.description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if let msg = refreshStatusMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                            Text(msg)
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            // Section 3: Plex Media Server Formatting Options
            VStack(alignment: .leading, spacing: 10) {
                Text("Plex Media Server Formatierungs-Optionen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Staffel-Ordnerbezeichnung:")
                            .font(.system(size: 12))
                            .foregroundColor(.white)

                        Picker("", selection: $settings.geminiPlexSeasonFolder) {
                            Text("Season (z. B. 'Season 01' – Offizieller Plex-Standard)").tag("Season")
                            Text("Staffel (z. B. 'Staffel 01' – Deutscher Standard)").tag("Staffel")
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle(isOn: $settings.geminiIncludeYear) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Erscheinungsjahr in Serientitel einbinden (z. B. 'Doctor Who (2005)')")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Text("Von Plex dringend empfohlen, um Verwechslungen bei Remakes oder Reboots zu vermeiden.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    // Plex Schema Summary
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💡 Offizielles Plex-Benennungsmuster:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                        Text("• Serien: Serientitel (Jahr) - s01e01 - Episodentitel.ext\n• Staffeln: Serientitel (Jahr)/\(settings.geminiPlexSeasonFolder) 01/Serientitel (Jahr) - s01e01 - Episodentitel.ext\n• Filme: Filmtitel (Jahr)/Filmtitel (Jahr).ext")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                }
                .padding(10)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }

    private func keyPlaceholder(for provider: AIProvider) -> String {
        switch provider {
        case .gemini: return "AIzaSy..."
        case .chatgpt: return "sk-..."
        case .claude: return "sk-ant-..."
        }
    }

    // MARK: - Tab 3: Account & Cookies
    private var accountTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $settings.useCookies) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Browser-Cookies für geschützte Videos nutzen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Ermöglicht den Download von YouTube Premium (1080p), Altersbeschränkungen sowie geschützten Mediathek-Inhalten.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            if settings.useCookies {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Browser für Account-Cookies wählen:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Picker("", selection: $settings.selectedBrowser) {
                            ForEach(SupportedBrowser.allCases) { b in
                                Label(b.displayName, systemImage: b.iconName).tag(b)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: settings.selectedBrowser) { _ in
                            cookieTestResult = nil
                        }

                        Button(action: testSelectedBrowserCookies) {
                            if isTestingCookies {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.shield")
                                    Text("Zugriff testen")
                                }
                                .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingCookies)
                    }

                    if let result = cookieTestResult {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(result.success ? .green : .orange)
                                .font(.system(size: 13))

                            Text(result.message)
                                .font(.system(size: 11))
                                .foregroundColor(result.success ? .green : .orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background((result.success ? Color.green : Color.orange).opacity(0.12))
                        .cornerRadius(6)
                    }

                    if settings.selectedBrowser == .customFile {
                        HStack {
                            TextField("Pfad zur cookies.txt...", text: $settings.customCookieFilePath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))

                            Button("Datei wählen...") {
                                chooseCookieFile()
                            }
                            .font(.system(size: 11))
                        }
                    }

                    // macOS Permission Box for Safari & other browsers
                    if settings.selectedBrowser != .customFile {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.orange)
                                Text("macOS-Sicherheitsanforderung für \(settings.selectedBrowser.displayName)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Apple schützt Safari- und Browserdaten vor anderen Apps. Falls beim Download 'Operation not permitted' erscheint:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Button("Systemeinstellungen: Festplattenvollzugriff öffnen") {
                                    openFullDiskAccessSettings()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .font(.system(size: 11, weight: .semibold))

                                Text("→ Haken bei 'Mac Video Loader' setzen")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Text("💡 Automatischer Fallback aktiv: Sollte macOS den Zugriff verweigern, lädt Mac Video Loader das Video automatisch ohne Account in bester öffentlicher Qualität herunter, statt mit einem Fehler abzubrechen.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.9))
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.25))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            // Info Callout
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vorteile der Browser-Cookie-Anmeldung")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Text("• Download von YouTube 1080p Premium mit erhöhter Bitrate\n• Zugriff auf altersbeschränkte Videos (Age-Gate) und Mediathek-Sperren\n• Zugriff auf private Playlists und geschützte Inhalte\n• Deine Zugangsdaten bleiben sicher in deinem Browser gespeichert.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Tab 3: Werkzeuge & Diagnose
    private var toolsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Backend-Dienste")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: refreshTools) {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
            }

            VStack(spacing: 8) {
                // yt-dlp Status
                toolRow(
                    name: "yt-dlp",
                    description: "Download- & Extraktions-Engine",
                    path: toolStatus.ytDlpPath,
                    version: toolStatus.ytDlpVersion
                )

                // FFmpeg Status
                toolRow(
                    name: "FFmpeg",
                    description: "Video-Muxer & Audio-Konverter",
                    path: toolStatus.ffmpegPath,
                    version: toolStatus.ffmpegVersion
                )

                // Node.js Status
                toolRow(
                    name: "JavaScript Runtime (Node)",
                    description: "Signatur- & Challenge-Solver",
                    path: toolStatus.nodePath,
                    version: nil
                )

                // Rename-Engine Status
                toolRow(
                    name: "Rename-CLI (Optional)",
                    description: "Lokale CLI für TMDb/TVDB-Abgleich (FileBot CLI falls vorhanden)",
                    path: toolStatus.filebotPath,
                    version: toolStatus.filebotVersion
                )
            }

            // Architecture Note on Ghidra
            VStack(alignment: .leading, spacing: 5) {
                Text("Hinweis zu Analysetools & Ghidra")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text("Ghidra ist ein NSA-Disassembler für kompilierte Maschinencode-Binärdateien. Für das Analysieren von Web- und Mediathek-Streams (DASH/HLS, Audio/Video-Codecs, Auflösungen) nutzt dieser Downloader die Formatanalyse von yt-dlp sowie die Stream-Inspektion von FFmpeg.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
        }
    }

    // MARK: - Tab 4: Changelog
    private var changelogTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Branding Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.1, green: 0.5, blue: 0.95), Color(red: 0.85, green: 0.15, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.blue.opacity(0.35), radius: 5, x: 0, y: 2)

                    Text("MVL")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Mac Video Loader")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("v0.6.0 (MVL)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    Text("Nativer Mac Video- & Mediatheken-Downloader (ARD, ZDF, Arte, YouTube & Web)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.black.opacity(0.25))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))

            // Changelog Entries
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Versionshistorie")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("23. Oktober 2026")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    changelogSection(
                        icon: "folder.badge.plus",
                        color: .blue,
                        title: "Version 0.6.0 - Freie Zielordner-Wahl in der Übersicht & Stapel-Download",
                        items: [
                            "Freie Zielordner-Wahl in der Übersicht: Direkt beim Einfügen von Video- oder Webseiten-Links kann ein individueller Zielordner für den anstehenden Download ausgewählt werden.",
                            "Automatischer Fallback: Bleibt das Feld unberührt oder wird zurückgesetzt, wird nahtlos der Standard-Zielordner genutzt.",
                            "Stapel-Download mit Zielordner-Wahl: Auch im Dialog 'Mehrere URLs...' (BatchAddSheet) kann direkt ein spezifischer Zielordner festgelegt oder angepasst werden.",
                            "Drag & Drop von Ordnern: Zielordner können direkt aus dem Finder per Drag & Drop auf die Zielordner-Leiste in der Übersicht abgelegt werden.",
                            "Playlist- & Staffel-Routing: Serien- und Playlisten-Downloads berücksichtigen den gewählten Basisordner und strukturieren Staffeln und Episoden sauber darunter.",
                            "Smarte Ordner-Pille in der Warteschlange: Einträge visualisieren ihren Zielordner übersichtlich, inklusive Hover-Tooltip für den vollständigen Pfad."
                        ]
                    )

                    changelogSection(
                        icon: "globe.americas.fill",
                        color: .purple,
                        title: "Version 0.5.2 - Open Source Release, GitHub Deployment & CC BY-NC 4.0",
                        items: [
                            "Offizielles Open-Source-Release auf GitHub unter github.com/mrgoldsmitt/Mac-Video-Loader.",
                            "Creative Commons Namensnennung - Nicht-kommerziell 4.0 Lizenzierung (CC BY-NC 4.0): Freie Weitergabe unter Nennung von Autor 'mrgoldsmitt', keine kommerzielle Nutzung.",
                            "Lizenz- und Urheberrechtsansicht direkt im Einstellungen-Fenster (Reiter Allgemein) integriert.",
                            "Automatisierte Deployment-Pipeline (deploy_release.sh) zum Bauen, Signieren, Taggen und Release-Upload via GitHub CLI.",
                            "Vollständige Anonymisierung & Datenschutzbereinigung des gesamten Codebases."
                        ]
                    )

                    changelogSection(
                        icon: "bolt.badge.clock.fill",
                        color: .green,
                        title: "Version 0.5.1 - Container-Optimierung & Fehler-Kategorie am Listenende",
                        items: [
                            "Container-Optimierung beschleunigt: Bevorzugt native progressive MP4-Streams bei Mediatheken (ZDF, ARD), wodurch langwierige MPEG-TS-Fixup- und Remuxing-Schritte entfallen und Videos direkt als MP4 geladen werden.",
                            "FFmpeg & StandardInput-Absicherung: Post-Processing läuft mit -nostdin, -threads 0, -y und standardInput = FileHandle.nullDevice, um Blockaden durch Eingabeaufforderungen oder Google Drive Dateisperren zu verhindern.",
                            "Automatischer Post-Processing Watchdog: Erkennt Stalls bei der Container-Optimierung (> 60s) und startet den Download automatisch nahtlos mit --continue neu (kein manuelles Pausieren/Fortsetzen mehr nötig).",
                            "Eigene Fehler-Kategorie am Listenende: Fehlgeschlagene Downloads werden in einem eigenen, roten Bereich am Ende der Liste zusammengefasst – inklusive Ausklapp-Funktion und 1-Klick-Buttons 'Alle wiederholen' und 'Alle entfernen'."
                        ]
                    )

                    changelogSection(
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        color: .blue,
                        title: "Version 0.5.0 - Ausfallsicherheit, Pause/Skip, Warteschlangen-Persistenz & .mvl-Listen",
                        items: [
                            "Automatische Wiederaufnahme bei Systemunterbrechungen: Downloads werden nach Netzwerkabbrüchen, WLAN-Verlust oder Mac-Ruhezustand automatisch und nahtlos mit exponentiellem Backoff fortgesetzt.",
                            "macOS SleepPreventionService: Verhindert über IOKit Power Assertions den Ruhezustand des Macs während aktiver Downloads (und gibt ihn nach Abschluss sofort wieder frei).",
                            "NetworkMonitorService: Automatische Überwachung der Netzwerkverbindung per NWPathMonitor und sofortiges Wiederanlaufen pausierter oder unterbrochener Downloads bei Reconnect.",
                            "Pause / Fortsetzen (Einzeln & Global): Neuer Pause/Weiter-Button direkt an jedem Download-Eintrag sowie globale Buttons 'Alle pausieren' und 'Alle fortsetzen'.",
                            "Überspringen (Pro Download & Pro Staffel): Neuer 'Überspringen' (⏭)-Button an jedem Download und im Rechtsklick-Kontextmenü 'Staffel überspringen' sowie 'Serie überspringen'.",
                            "Dauerhafte Warteschlangen-Persistenz: Warteschlange wird automatisch in ~/Library/Application Support/Mac Video Loader/queue.json gespeichert und bei App-Neustart exakt wiederhergestellt.",
                            "Multi-Selektion & Stapel-Aktionen: Downloads können per Checkbox mehrfach ausgewählt werden. Neue Aktionsleiste ermöglicht gemeinsames Fortsetzen, Pausieren, Überspringen oder Entfernen.",
                            "Download-Listen speichern & laden (.mvl): Warteschlangen können als portable .mvl-Dateien (JSON) inkl. aller Metadaten exportiert, importiert und per Drag & Drop in die App gezogen werden.",
                            "Wiederhergestellte Downloads: Die 187 Downloads der letzten Nacht (122 Folgen 'Die Biene Maja' & 65 Folgen 'Flash Gordon') wurden vollständig rekonstruiert und stehen sofort in der Warteschlange bereit."
                        ]
                    )

                    changelogSection(
                        icon: "folder.badge.gearshape",
                        color: .yellow,
                        title: "Version 0.4.0 - Eigene Serien- & Staffel-Ordner, Playlist- & Mediathek-Fixes (MVL)",
                        items: [
                            "Automatische Serien- & Staffel-Ordner: Episoden aus Mediatheken werden automatisch in saubere Unterordner <Serie>/<Staffel>/ (z. B. 'Die Biene Maja/Staffel 1') einsortiert.",
                            "Dedizierte Playlist-Ordner: Videos aus YouTube- oder Web-Playlists werden direkt in einem Unterordner mit dem Playlist-Namen gespeichert.",
                            "Zielordner-Vorschau: Das Playlist- und Staffelfenster zeigt vor dem Download exakt an, in welche Verzeichnisse die Dateien geladen werden.",
                            "Ordner-Pille in der Warteschlange: Jeder Download-Eintrag zeigt seinen spezifischen Serien- oder Playlist-Ordner dezent an.",
                            "Robuste Playlist-Inspektion mit Cookie-Fallback: macOS-Sicherheitsblockaden (TCC 'Operation not permitted') bei Safari-Cookies brechen die Playlist-Erkennung nicht mehr ab, sondern führen automatisch einen Fallback durch.",
                            "YouTube Kombi-URLs gefixt: Links mit Video & Playlist ('watch?v=...&list=...') erzwingen jetzt die Erkennung der kompletten Playlist statt nur des Einzelvideos.",
                            "ZDF Mediathek Staffelerkennung optimiert: Sendungen und Serien (z. B. Die Biene Maja) werden vollständig analysiert und öffnen verlässlich das interaktive Auswahlfenster ohne ungewollten Vorab-Download.",
                            "SwiftUI Sheet-Kollision behoben: Unabhängige Fensterverwaltung verhindert das Blockieren von Dialogen unter macOS."
                        ]
                    )

                    changelogSection(
                        icon: "tv.inset.filled",
                        color: .green,
                        title: "Version 0.3.0 - Mediatheken-Staffeln & Live-Analyse (MVL)",
                        items: [
                            "Ganze Staffeln herunterladen: Vollständiger Staffel- und Seriendownload für ARD Mediathek, ZDF und Arte bis zu 500 Episoden pro Serie.",
                            "Automatische Staffel-Erkennung aus Einzelfolgen: Erkennt beim Einfügen eines Links zu einer einzelnen Mediathek-Folge automatisch die gesamte übergeordnete Staffel.",
                            "Interaktive Staffel-Filter-Chips: Schnelles Umschalten zwischen Staffeln ('Alle', 'Staffel 1', 'Staffel 2' etc.) mit Live-Episodenzähler.",
                            "Staffel-Schnellwahl: Neuer Button 'Nur diese Staffel auswählen' zur 1-Klick-Auswahl einer kompletten Staffel.",
                            "Staffel- & Episoden-Badges: Visuelle Kennzeichnung jeder Folge mit Serien-/Staffel-Badge (z. B. 'S01 • E01', 'Staffel 1') im Auswahldialog.",
                            "Echtzeit-Fortschrittsbalken: Exakte prozentuale Fortschrittsanzeige mit Titel-Vorschau und Zähler ('Video X von Y erfasst: [Titel]...') während der Playlist-Analyse.",
                            "Sofortiger Abbruch: Laufende Erkennungen können jederzeit per rotem Button, 'Esc' oder ⌘. sofort gestoppt werden, ohne dass die URL zur Warteschlange hinzugefügt wird."
                        ]
                    )

                    changelogSection(
                        icon: "sparkles",
                        color: .blue,
                        title: "Version 0.2.0 - Universal Web Downloader & Rebranding (MVL)",
                        items: [
                            "Rebranding zu 'Mac Video Loader' (MVL): Vollständige Neuausrichtung mit frischer Markenidentität und Retina-App-Icon.",
                            "Universelle Web-Extraktion: Herunterladen von Videos von beliebigen Webseiten – automatische Erkennung der optimalen Video- und Audioquellen.",
                            "Öffentlich-rechtliche Mediatheken: Volle native Integration für ARD Mediathek, ZDF, Arte, 3sat, KiKa, SWR, WDR, NDR, BR, MDR und weitere Sender.",
                            "Interaktiver Auswahldialog: Einzelne Titel vor dem Download an- oder abwählen mit Live-Zähler ('X von Y ausgewählt').",
                            "Echtzeit-Suche & Schnellwahl: Schnelles Filtern in großen Playlists sowie 'Alle auswählen' / 'Keine auswählen'-Buttons.",
                            "Flexibles Format-Muxing: Freie Wahl zwischen MP4 (bis zu bester verfügbarer 4K/8K-Auflösung) und reinem Audio (MP3 320 kbps, M4A, FLAC, WAV, Opus) auch für Batch-Downloads."
                        ]
                    )

                    changelogSection(
                        icon: "clock.arrow.circlepath",
                        color: .secondary,
                        title: "Version 0.1.0 - Initiales Release (YTDownloader)",
                        items: [
                            "Video-Download (MP4): Qualitätsstufen von 360p bis 4K/8K Ultra HD mit verlustfreiem FFmpeg-Muxing.",
                            "Audio-Extraktion: Direkter Tonspur-Download in MP3 (320 kbps), M4A/AAC (Apple-Standard), FLAC (lossless), WAV und Opus.",
                            "Browser-Cookies: Unterstützung für Safari, Chrome, Brave, Firefox, Edge oder eigene cookies.txt.",
                            "macOS TCC-Schutz & Fallback: Intelligente Fallback-Logik fängt Zugriffsblockaden ab und lädt Videos ohne Account weiter.",
                            "Warteschlange & Stapel-Download: Gleichzeitige Downloads (1–6 Slots), Multi-URL-Import und Drag-and-Drop.",
                            "System-Integration & DMG: 1-Klick-Installation nach /Applications, Deinstallation und portables Disk-Image."
                        ]
                    )
                }
            }
        }
    }

    private func changelogSection(icon: String, color: Color, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11, weight: .bold))
                        Text(item)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 6)
        }
        .padding(12)
        .background(Color.black.opacity(0.25))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func toolRow(name: String, description: String, path: String?, version: String?) -> some View {
        HStack {
            Image(systemName: path != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(path != nil ? .green : .red)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    if let ver = version {
                        Text("v\(ver)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                Text(path ?? "Nicht installiert / nicht gefunden")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.black.opacity(0.25))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Auswählen"

        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadFolder = url
        }
    }

    private func chooseCookieFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Auswählen"

        if panel.runModal() == .OK, let url = panel.url {
            settings.customCookieFilePath = url.path
        }
    }

    private func performInstall() {
        switch installationService.install() {
        case .success:
            installStatusMessage = "Erfolgreich in /Applications installiert!"
        case .failure(let error):
            installStatusMessage = "Fehler: \(error.localizedDescription)"
        }
    }

    private func performUninstall() {
        switch installationService.uninstall() {
        case .success:
            installStatusMessage = "Erfolgreich deinstalliert."
        case .failure(let error):
            installStatusMessage = "Fehler: \(error.localizedDescription)"
        }
    }

    private func testSelectedBrowserCookies() {
        isTestingCookies = true
        cookieTestResult = nil
        Task {
            let res = await YTDlpService.shared.testBrowserCookies(
                browser: settings.selectedBrowser,
                customPath: settings.customCookieFilePath
            )
            await MainActor.run {
                self.cookieTestResult = res
                self.isTestingCookies = false
            }
        }
    }

    private func testCurrentApiKey() {
        let provider = settings.selectedAIProvider
        isTestingAI = true
        aiTestResult = nil
        let keyToTest = currentApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.getModel(for: provider)
        Task {
            let res = await AIService.shared.testApiKey(
                provider: provider,
                apiKey: keyToTest,
                model: model
            )
            await MainActor.run {
                self.aiTestResult = res
                self.isTestingAI = false
                if res.success {
                    settings.setApiKey(keyToTest, for: provider)
                    Task {
                        isRefreshingModels = true
                        let modelRes = await settings.refreshModels(for: provider)
                        isRefreshingModels = false
                        refreshStatusMessage = modelRes.message
                    }
                }
            }
        }
    }

    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshTools() {
        toolStatus = SystemService.shared.checkToolsStatus(
            customYtDlp: settings.customYtDlpPath,
            customFfmpeg: settings.customFfmpegPath,
            customFilebot: settings.customFilebotPath
        )
    }
}
