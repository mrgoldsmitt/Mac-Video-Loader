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
        static let selectedAIProvider = "selectedAIProvider"
        static let chatgptModel = "chatgptModel"
        static let claudeModel = "claudeModel"
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

    // Rename Studio properties (aliases)
    public var customRenameCliPath: String {
        get { customFilebotPath }
        set { customFilebotPath = newValue }
    }
    public var renameDefaultMode: String {
        get { filebotDefaultMode }
        set { filebotDefaultMode = newValue }
    }
    public var renameLanguage: String {
        get { filebotLanguage }
        set { filebotLanguage = newValue }
    }
    public var renameDatabase: String {
        get { filebotDatabase }
        set { filebotDatabase = newValue }
    }

    @Published public var selectedAIProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(selectedAIProvider.rawValue, forKey: Keys.selectedAIProvider)
        }
    }

    @Published public var chatgptModel: String {
        didSet {
            UserDefaults.standard.set(chatgptModel, forKey: Keys.chatgptModel)
        }
    }

    @Published public var claudeModel: String {
        didSet {
            UserDefaults.standard.set(claudeModel, forKey: Keys.claudeModel)
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
    @Published public var hasChatGPTApiKey: Bool = false
    @Published public var hasClaudeApiKey: Bool = false

    public func getApiKey(for provider: AIProvider) -> String {
        return KeychainService.shared.load(forAccount: provider.keychainAccount) ?? ""
    }

    public func setApiKey(_ key: String, for provider: AIProvider) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            deleteApiKey(for: provider)
        } else {
            _ = KeychainService.shared.save(key: clean, forAccount: provider.keychainAccount)
            updateApiKeyStatus(for: provider, hasKey: true)
        }
    }

    public func deleteApiKey(for provider: AIProvider) {
        _ = KeychainService.shared.delete(forAccount: provider.keychainAccount)
        updateApiKeyStatus(for: provider, hasKey: false)
    }

    public func hasApiKey(for provider: AIProvider) -> Bool {
        return !getApiKey(for: provider).isEmpty
    }

    private func updateApiKeyStatus(for provider: AIProvider, hasKey: Bool) {
        switch provider {
        case .gemini:
            hasGeminiApiKey = hasKey
        case .chatgpt:
            hasChatGPTApiKey = hasKey
        case .claude:
            hasClaudeApiKey = hasKey
        }
    }

    public func getModel(for provider: AIProvider) -> String {
        switch provider {
        case .gemini: return geminiModel
        case .chatgpt: return chatgptModel
        case .claude: return claudeModel
        }
    }

    public func setModel(_ model: String, for provider: AIProvider) {
        switch provider {
        case .gemini: geminiModel = model
        case .chatgpt: chatgptModel = model
        case .claude: claudeModel = model
        }
    }

    public var currentAIModel: String {
        get { getModel(for: selectedAIProvider) }
        set { setModel(newValue, for: selectedAIProvider) }
    }

    public var currentAIApiKey: String {
        getApiKey(for: selectedAIProvider)
    }

    public var hasCurrentAIApiKey: Bool {
        hasApiKey(for: selectedAIProvider)
    }

    // Backward compatibility aliases
    public func getGeminiApiKey() -> String {
        return getApiKey(for: .gemini)
    }

    public func setGeminiApiKey(_ key: String) {
        setApiKey(key, for: .gemini)
    }

    public func deleteGeminiApiKey() {
        deleteApiKey(for: .gemini)
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

        if let rawProvider = UserDefaults.standard.string(forKey: Keys.selectedAIProvider),
           let provider = AIProvider(rawValue: rawProvider) {
            self.selectedAIProvider = provider
        } else {
            self.selectedAIProvider = .gemini
        }

        self.chatgptModel = UserDefaults.standard.string(forKey: Keys.chatgptModel) ?? AIProvider.chatgpt.defaultModel
        self.claudeModel = UserDefaults.standard.string(forKey: Keys.claudeModel) ?? AIProvider.claude.defaultModel
        self.geminiModel = UserDefaults.standard.string(forKey: Keys.geminiModel) ?? AIProvider.gemini.defaultModel
        self.geminiPlexSeasonFolder = UserDefaults.standard.string(forKey: Keys.geminiPlexSeasonFolder) ?? "Season"
        if UserDefaults.standard.object(forKey: Keys.geminiIncludeYear) == nil {
            self.geminiIncludeYear = true
        } else {
            self.geminiIncludeYear = UserDefaults.standard.bool(forKey: Keys.geminiIncludeYear)
        }
        self.hasGeminiApiKey = !(KeychainService.shared.load(forAccount: AIProvider.gemini.keychainAccount) ?? "").isEmpty
        self.hasChatGPTApiKey = !(KeychainService.shared.load(forAccount: AIProvider.chatgpt.keychainAccount) ?? "").isEmpty
        self.hasClaudeApiKey = !(KeychainService.shared.load(forAccount: AIProvider.claude.keychainAccount) ?? "").isEmpty

        // Ensure default download folder exists
        try? FileManager.default.createDirectory(at: self.downloadFolder, withIntermediateDirectories: true)
    }
}
