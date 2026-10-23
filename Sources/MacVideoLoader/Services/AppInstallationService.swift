import Foundation
import AppKit

public class AppInstallationService: ObservableObject {
    public static let shared = AppInstallationService()

    public let applicationsAppURL = URL(fileURLWithPath: "/Applications/Mac Video Loader.app")

    @Published public var isInstalled: Bool = false
    @Published public var isRunningFromApplications: Bool = false

    private init() {
        checkStatus()
    }

    public func checkStatus() {
        isInstalled = FileManager.default.fileExists(atPath: applicationsAppURL.path)
        let currentBundle = Bundle.main.bundleURL
        isRunningFromApplications = currentBundle.path.hasPrefix("/Applications/")
    }

    public func install() -> Result<Void, Error> {
        let bundleURL = Bundle.main.bundleURL
        var sourceAppURL: URL? = nil

        if bundleURL.pathExtension == "app" {
            sourceAppURL = bundleURL
        } else {
            // Find Mac Video Loader.app in current directory or near executable
            let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let currentDirApp = currentDir.appendingPathComponent("Mac Video Loader.app")
            let fallbackDirApp = currentDir.appendingPathComponent("YTDownloader.app")

            if FileManager.default.fileExists(atPath: currentDirApp.path) {
                sourceAppURL = currentDirApp
            } else if FileManager.default.fileExists(atPath: fallbackDirApp.path) {
                sourceAppURL = fallbackDirApp
            } else {
                let executableDir = bundleURL.deletingLastPathComponent()
                let nearApp = executableDir.appendingPathComponent("Mac Video Loader.app")
                if FileManager.default.fileExists(atPath: nearApp.path) {
                    sourceAppURL = nearApp
                }
            }
        }

        guard let source = sourceAppURL else {
            return .failure(NSError(
                domain: "MacVideoLoader",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Mac Video Loader.app Quell-Datei nicht gefunden. Bitte führe ./bundle_app.sh aus."]
            ))
        }

        do {
            if FileManager.default.fileExists(atPath: applicationsAppURL.path) {
                try FileManager.default.removeItem(at: applicationsAppURL)
            }

            try FileManager.default.copyItem(at: source, to: applicationsAppURL)

            // Remove quarantine attribute and re-sign ad-hoc
            let xattrProc = Process()
            xattrProc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattrProc.arguments = ["-cr", applicationsAppURL.path]
            try? xattrProc.run()
            xattrProc.waitUntilExit()

            let signProc = Process()
            signProc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            signProc.arguments = ["--force", "--deep", "--sign", "-", applicationsAppURL.path]
            try? signProc.run()
            signProc.waitUntilExit()

            DispatchQueue.main.async {
                self.checkStatus()
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    public func uninstall(deletePreferences: Bool = false) -> Result<Void, Error> {
        do {
            if FileManager.default.fileExists(atPath: applicationsAppURL.path) {
                try FileManager.default.removeItem(at: applicationsAppURL)
            }

            if deletePreferences {
                if let bundleId = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleId)
                }
                UserDefaults.standard.removePersistentDomain(forName: "com.macvideoloader")
                UserDefaults.standard.synchronize()
            }

            DispatchQueue.main.async {
                self.checkStatus()
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
