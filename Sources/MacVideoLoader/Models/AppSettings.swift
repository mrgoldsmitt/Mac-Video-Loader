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
        static let askToRenameAfterDownload = "askToRenameAfterDownload"
        static let customFilebotPath = "customFilebotPath"
        static let filebotDefaultMode = "filebotDefaultMode"
        static let filebotLanguage = "filebotLanguage"
        static let filebotDatabase = "filebotDatabase"
        static let geminiModel = "geminiModel"
        static let geminiPlexSeasonFolder = "geminiPlexSeasonFolder"
        static let geminiIncludeYear = "geminiIncludeYear"
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

    @Published public var askToRenameAfterDownload: Bool {
        didSet {
            UserDefaults.standard.set(askToRenameAfterDownload, forKey: Keys.askToRenameAfterDownload)
        }
    }

    @Published public var customFilebotPath: String {
        didSet {
            UserDefaults.standard.set(customFilebotPath, forKey: Keys.customFilebotPath)
        }
    }

    @Published public var filebotDefaultMode: String {
        didSet {
            UserDefaults.standard.set(filebotDefaultMode, forKey: Keys.filebotDefaultMode)
        }
    }

    @Published public var filebotLanguage: String {
        didSet {
            UserDefaults.standard.set(filebotLanguage, forKey: Keys.filebotLanguage)
        }
    }

    @Published public var filebotDatabase: String {
        didSet {
            UserDefaults.standard.set(filebotDatabase, forKey: Keys.filebotDatabase)
        }
    }

    @Published public var geminiModel: String {
        didSet {
            UserDefaults.standard.set(geminiModel, forKey: Keys.geminiModel)
        }
    }

    @Published public var geminiPlexSeasonFolder: String {
        didSet {
            UserDefaults.standard.set(geminiPlexSeasonFolder, forKey: Keys.geminiPlexSeasonFolder)
        }
    }

    @Published public var geminiIncludeYear: Bool {
        didSet {
            UserDefaults.standard.set(geminiIncludeYear, forKey: Keys.geminiIncludeYear)
        }
    }

    @Published public var hasGeminiApiKey: Bool = false

    public func getGeminiApiKey() -> String {
        return KeychainService.shared.load(forAccount: "gemini_api_key") ?? ""
    }

    public func setGeminiApiKey(_ key: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            deleteGeminiApiKey()
        } else {
            _ = KeychainService.shared.save(key: clean, forAccount: "gemini_api_key")
            hasGeminiApiKey = true
        }
    }

    public func deleteGeminiApiKey() {
        _ = KeychainService.shared.delete(forAccount: "gemini_api_key")
        hasGeminiApiKey = false
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

        if UserDefaults.standard.object(forKey: Keys.askToRenameAfterDownload) == nil {
            self.askToRenameAfterDownload = true
        } else {
            self.askToRenameAfterDownload = UserDefaults.standard.bool(forKey: Keys.askToRenameAfterDownload)
        }

        self.customFilebotPath = UserDefaults.standard.string(forKey: Keys.customFilebotPath) ?? ""
        self.filebotDefaultMode = UserDefaults.standard.string(forKey: Keys.filebotDefaultMode) ?? "series"
        self.filebotLanguage = UserDefaults.standard.string(forKey: Keys.filebotLanguage) ?? "German"
        self.filebotDatabase = UserDefaults.standard.string(forKey: Keys.filebotDatabase) ?? "TheMovieDB::TV"

        self.geminiModel = UserDefaults.standard.string(forKey: Keys.geminiModel) ?? "gemini-2.5-flash"
        self.geminiPlexSeasonFolder = UserDefaults.standard.string(forKey: Keys.geminiPlexSeasonFolder) ?? "Season"
        if UserDefaults.standard.object(forKey: Keys.geminiIncludeYear) == nil {
            self.geminiIncludeYear = true
        } else {
            self.geminiIncludeYear = UserDefaults.standard.bool(forKey: Keys.geminiIncludeYear)
        }
        self.hasGeminiApiKey = !(KeychainService.shared.load(forAccount: "gemini_api_key") ?? "").isEmpty

        // Ensure default download folder exists
        try? FileManager.default.createDirectory(at: self.downloadFolder, withIntermediateDirectories: true)
    }
}
