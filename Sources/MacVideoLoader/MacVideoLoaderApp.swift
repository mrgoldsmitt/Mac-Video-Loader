import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct MacVideoLoaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                Button("In Programme-Ordner (/Applications) installieren") {
                    let result = AppInstallationService.shared.install()
                    let alert = NSAlert()
                    switch result {
                    case .success:
                        alert.messageText = "Installation erfolgreich"
                        alert.informativeText = "Mac Video Loader wurde nach /Applications kopiert."
                        alert.alertStyle = .informational
                    case .failure(let error):
                        alert.messageText = "Installationsfehler"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                    }
                    alert.runModal()
                }

                Button("Aus Programme-Ordner deinstallieren") {
                    let alert = NSAlert()
                    alert.messageText = "Mac Video Loader deinstallieren?"
                    alert.informativeText = "Möchtest du Mac Video Loader aus /Applications löschen?"
                    alert.addButton(withTitle: "Deinstallieren")
                    alert.addButton(withTitle: "Abbrechen")
                    alert.alertStyle = .critical

                    if alert.runModal() == .alertFirstButtonReturn {
                        _ = AppInstallationService.shared.uninstall()
                    }
                }
                Divider()
                Button("Festplattenvollzugriff (Datenschutz) öffnen...") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Divider()
            }
            CommandGroup(replacing: .newItem) {
                Button("Zwischenablage einfügen") {
                    if let string = NSPasteboard.general.string(forType: .string) {
                        DownloadManager.shared.analyzeOrAddURL(
                            string,
                            downloadType: .video,
                            videoQuality: .best,
                            audioFormat: .mp3
                        )
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Divider()

                Button("Download-Liste öffnen...") {
                    DownloadManager.shared.importListFromPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Download-Liste speichern...") {
                    DownloadManager.shared.exportSelectedOrAllList()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
            CommandMenu("Downloads") {
                Button("Analyse abbrechen") {
                    DownloadManager.shared.cancelAnalysis()
                }
                .keyboardShortcut(".", modifiers: [.command])

                Divider()

                Button("Alle markieren") {
                    DownloadManager.shared.selectAll()
                }
                .keyboardShortcut("a", modifiers: [.command])

                Button("Auswahl aufheben") {
                    DownloadManager.shared.deselectAll()
                }

                Divider()

                Button("Alle fortsetzen") {
                    DownloadManager.shared.resumeAll()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Alle pausieren") {
                    DownloadManager.shared.pauseAll()
                }
                .keyboardShortcut("p", modifiers: [.command])

                Divider()

                Button("Markierte starten") {
                    DownloadManager.shared.resumeSelected()
                }

                Button("Markierte pausieren") {
                    DownloadManager.shared.pauseSelected()
                }

                Button("Markierte überspringen") {
                    DownloadManager.shared.skipSelected()
                }

                Divider()

                Button("Fertige aufräumen") {
                    DownloadManager.shared.clearCompleted()
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
    }
}
