import Foundation

public enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case gemini = "gemini"
    case chatgpt = "chatgpt"
    case claude = "claude"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .chatgpt: return "ChatGPT (OpenAI)"
        case .claude: return "Claude (Anthropic)"
        }
    }

    public var shortName: String {
        switch self {
        case .gemini: return "Gemini"
        case .chatgpt: return "ChatGPT"
        case .claude: return "Claude"
        }
    }

    public var icon: String {
        switch self {
        case .gemini: return "sparkles"
        case .chatgpt: return "brain"
        case .claude: return "bubble.left.and.text.bubble.right.fill"
        }
    }

    public var keychainAccount: String {
        switch self {
        case .gemini: return "gemini_api_key"
        case .chatgpt: return "chatgpt_api_key"
        case .claude: return "claude_api_key"
        }
    }

    public var portalURL: URL {
        switch self {
        case .gemini: return URL(string: "https://aistudio.google.com/app/apikey")!
        case .chatgpt: return URL(string: "https://platform.openai.com/api-keys")!
        case .claude: return URL(string: "https://console.anthropic.com/settings/keys")!
        }
    }

    public var portalDisplayName: String {
        switch self {
        case .gemini: return "aistudio.google.com"
        case .chatgpt: return "platform.openai.com"
        case .claude: return "console.anthropic.com"
        }
    }

    public var defaultModel: String {
        switch self {
        case .gemini: return "gemini-2.5-flash-lite"
        case .chatgpt: return "gpt-4o-mini"
        case .claude: return "claude-3-5-haiku-20241022"
        }
    }
}

public struct AIModelOption: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let provider: AIProvider
    public let displayName: String
    public let description: String
    public let isRecommended: Bool

    public init(
        id: String,
        provider: AIProvider,
        displayName: String,
        description: String,
        isRecommended: Bool = false
    ) {
        self.id = id
        self.provider = provider
        self.displayName = displayName
        self.description = description
        self.isRecommended = isRecommended
    }

    public static func models(for provider: AIProvider) -> [AIModelOption] {
        switch provider {
        case .gemini:
            return [
                AIModelOption(
                    id: "gemini-2.5-flash-lite",
                    provider: .gemini,
                    displayName: "Gemini 2.5 Flash-Lite",
                    description: "Empfohlen: Ultraschnell, ressourceneffizient & präzise",
                    isRecommended: true
                ),
                AIModelOption(
                    id: "gemini-2.5-pro",
                    provider: .gemini,
                    displayName: "Gemini 2.5 Pro",
                    description: "Maximale Genauigkeit für komplexe Titel & Serienstrukturen",
                    isRecommended: false
                ),
                AIModelOption(
                    id: "gemini-1.5-flash",
                    provider: .gemini,
                    displayName: "Gemini 1.5 Flash",
                    description: "Bewährtes & stabiles Allround-Modell",
                    isRecommended: false
                ),
                AIModelOption(
                    id: "gemini-1.5-pro",
                    provider: .gemini,
                    displayName: "Gemini 1.5 Pro",
                    description: "Großes Kontextfenster für komplexe Strukturen",
                    isRecommended: false
                )
            ]
        case .chatgpt:
            return [
                AIModelOption(
                    id: "gpt-4o-mini",
                    provider: .chatgpt,
                    displayName: "GPT-4o Mini",
                    description: "Empfohlen: Ultraschnell, kostengünstig & hochpräzise",
                    isRecommended: true
                ),
                AIModelOption(
                    id: "gpt-4o",
                    provider: .chatgpt,
                    displayName: "GPT-4o",
                    description: "Omni-Flaggschiffmodell von OpenAI für komplexe Aufgaben",
                    isRecommended: false
                ),
                AIModelOption(
                    id: "o3-mini",
                    provider: .chatgpt,
                    displayName: "o3-mini",
                    description: "Neuestes Reasoning-Modell für tiefes logisches Durchdenken",
                    isRecommended: false
                ),
                AIModelOption(
                    id: "o1-mini",
                    provider: .chatgpt,
                    displayName: "o1-mini",
                    description: "Kompaktes Reasoning-Modell",
                    isRecommended: false
                ),
                AIModelOption(
                    id: "o1",
                    provider: .chatgpt,
                    displayName: "o1",
                    description: "Leistungsstarkes Reasoning-Flaggschiff",
                    isRecommended: false
                ),
                AIModelOption(
                    id: "gpt-4-turbo",
                    provider: .chatgpt,
                    displayName: "GPT-4 Turbo",
                    description: "Klassisches Spitzenmodell von OpenAI",
                    isRecommended: false
                )
            ]
        case .claude:
            return [
                AIModelOption(
                    id: "claude-3-5-haiku-20241022",
                    provider: .claude,
                    displayName: "Claude 3.5 Haiku",
                    description: "Empfohlen: Ultraschnell & kostengünstig",
                    isRecommended: true
                ),
                AIModelOption(
                    id: "claude-3-7-sonnet-20250219",
                    provider: .claude,
                    displayName: "Claude 3.7 Sonnet",
                    description: "Neuestes Hybrid-Reasoning-Modell für maximale Intelligenz",
                    isRecommended: false
                ),
                AIModelOption(
                    id: "claude-3-5-sonnet-20241022",
                    provider: .claude,
                    displayName: "Claude 3.5 Sonnet",
                    description: "Branchenführende Textanalyse & Detailtreue",
                    isRecommended: false
                ),
                AIModelOption(
                    id: "claude-3-opus-20240229",
                    provider: .claude,
                    displayName: "Claude 3 Opus",
                    description: "Klassisches Spitzenmodell von Anthropic",
                    isRecommended: false
                )
            ]
        }
    }
}

public typealias GeminiModelOption = AIModelOption

extension GeminiModelOption {
    public static var availableModels: [AIModelOption] {
        models(for: .gemini)
    }
}

public struct PlexNamingProposal: Codable, Sendable {
    public let originalName: String
    public let seriesName: String
    public let year: Int?
    public let seasonNumber: Int
    public let episodeNumber: Int
    public let episodeTitle: String
    public let isMovie: Bool?
    public let plexSeriesFileName: String
    public let plexSeasonPath: String
    public let reasoning: String?

    public init(
        originalName: String,
        seriesName: String,
        year: Int? = nil,
        seasonNumber: Int = 1,
        episodeNumber: Int = 1,
        episodeTitle: String = "",
        isMovie: Bool? = false,
        plexSeriesFileName: String,
        plexSeasonPath: String,
        reasoning: String? = nil
    ) {
        self.originalName = originalName
        self.seriesName = seriesName
        self.year = year
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle
        self.isMovie = isMovie
        self.plexSeriesFileName = plexSeriesFileName
        self.plexSeasonPath = plexSeasonPath
        self.reasoning = reasoning
    }
}

public struct CustomFileNamingProposal: Codable, Sendable {
    public let originalName: String
    public let proposedName: String
    public let proposedRelativePath: String?
    public let reasoning: String?

    public init(
        originalName: String,
        proposedName: String,
        proposedRelativePath: String? = nil,
        reasoning: String? = nil
    ) {
        self.originalName = originalName
        self.proposedName = proposedName
        self.proposedRelativePath = proposedRelativePath
        self.reasoning = reasoning
    }
}
