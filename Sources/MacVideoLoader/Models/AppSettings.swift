import Foundation
import Combine

public class AppSettings: ObservableObject, @unchecked Sendable {
    public static let shared = AppSettings()

    private enum Keys {
        static let downloadFolderPath = "downloadFolderPath"
        static let useCookies = "useCookies"
        static let selectedBrowser = "selectedBrowser"
        static let customCookieFilePath = "customCookieFilePath"
        static let maxConcurrentDownloads = "maxConcurrentDownloads"
        static let customYtDlpPath = "customYtDlpPath"
        static let customFfmpegPath = "customFfmpegPath"
    }

    @Published public var downloadFolder: URL {
        didSet {
            UserDefaults.standard.set(downloadFolder.path, forKey: Keys.downloadFolderPath)
        }
    }

    @Published public var useCookies: Bool {
        didSet {
            UserDefaults.standard.set(useCookies, forKey: Keys.useCookies)
        }
    }

    @Published public var selectedBrowser: SupportedBrowser {
        didSet {
            UserDefaults.standard.set(selectedBrowser.rawValue, forKey: Keys.selectedBrowser)
        }
    }

    @Published public var customCookieFilePath: String {
        didSet {
            UserDefaults.standard.set(customCookieFilePath, forKey: Keys.customCookieFilePath)
        }
    }

    @Published public var maxConcurrentDownloads: Int {
        didSet {
            UserDefaults.standard.set(maxConcurrentDownloads, forKey: Keys.maxConcurrentDownloads)
        }
    }

    @Published public var customYtDlpPath: String {
        didSet {
            UserDefaults.standard.set(customYtDlpPath, forKey: Keys.customYtDlpPath)
        }
    }

    @Published public var customFfmpegPath: String {
        didSet {
            UserDefaults.standard.set(customFfmpegPath, forKey: Keys.customFfmpegPath)
        }
    }

    public init() {
        // Default download directory: ~/Downloads/Mac Video Loader
        let defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Mac Video Loader")

        if let savedPath = UserDefaults.standard.string(forKey: Keys.downloadFolderPath) {
            self.downloadFolder = URL(fileURLWithPath: savedPath)
        } else {
            self.downloadFolder = defaultFolder
        }

        self.useCookies = UserDefaults.standard.bool(forKey: Keys.useCookies)

        if let browserRaw = UserDefaults.standard.string(forKey: Keys.selectedBrowser),
           let browser = SupportedBrowser(rawValue: browserRaw) {
            self.selectedBrowser = browser
        } else {
            self.selectedBrowser = .safari
        }

        self.customCookieFilePath = UserDefaults.standard.string(forKey: Keys.customCookieFilePath) ?? ""
        
        let savedMax = UserDefaults.standard.integer(forKey: Keys.maxConcurrentDownloads)
        self.maxConcurrentDownloads = savedMax > 0 ? savedMax : 2

        self.customYtDlpPath = UserDefaults.standard.string(forKey: Keys.customYtDlpPath) ?? ""
        self.customFfmpegPath = UserDefaults.standard.string(forKey: Keys.customFfmpegPath) ?? ""

        // Ensure default download folder exists
        try? FileManager.default.createDirectory(at: self.downloadFolder, withIntermediateDirectories: true)
    }
}
