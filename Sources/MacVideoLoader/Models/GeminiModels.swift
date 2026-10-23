import Foundation

public struct GeminiModelOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let isRecommended: Bool

    public static let availableModels: [GeminiModelOption] = [
        GeminiModelOption(
            id: "gemini-2.5-flash",
            displayName: "Gemini 2.5 Flash",
            description: "Empfohlen: Ultraschnell, kosteneffizient & ideal für Medien-Titel",
            isRecommended: true
        ),
        GeminiModelOption(
            id: "gemini-2.5-pro",
            displayName: "Gemini 2.5 Pro",
            description: "Maximale Genauigkeit für kryptische oder unvollständige Titel",
            isRecommended: false
        ),
        GeminiModelOption(
            id: "gemini-2.0-flash",
            displayName: "Gemini 2.0 Flash",
            description: "Schnelles Multitasking-Modell der 2. Generation",
            isRecommended: false
        ),
        GeminiModelOption(
            id: "gemini-1.5-flash",
            displayName: "Gemini 1.5 Flash",
            description: "Bewährtes, stabiles Flash-Modell",
            isRecommended: false
        ),
        GeminiModelOption(
            id: "gemini-1.5-pro",
            displayName: "Gemini 1.5 Pro",
            description: "Umfassendes Denkmodell mit großem Kontextfenster",
            isRecommended: false
        )
    ]
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
