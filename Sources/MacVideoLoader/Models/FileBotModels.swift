import Foundation
import Combine

public enum FileBotProcessingMode: String, CaseIterable, Identifiable, Codable {
    case series = "series"
    case season = "season"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .series:
            return "Serienverarbeitung"
        case .season:
            return "Staffelverarbeitung"
        case .custom:
            return "Dateien & Markup"
        }
    }

    public var subtitle: String {
        switch self {
        case .series:
            return "Benennt Folgen einheitlich um (z. B. 'Serie - S01E01 - Titel.mp4')"
        case .season:
            return "Strukturiert Folgen in Staffel-Ordnern (z. B. 'Serie/Staffel 01/Serie - S01E01 - Titel.mp4')"
        case .custom:
            return "Benennt beliebige Dateien nach eigenem Schema, Filtern oder KI-Anweisung um"
        }
    }

    public var icon: String {
        switch self {
        case .series:
            return "tv.fill"
        case .season:
            return "folder.badge.gearshape"
        case .custom:
            return "slider.horizontal.2.square"
        }
    }

    public var defaultFormat: String {
        switch self {
        case .series:
            return "{n} - {s00e00} - {t}"
        case .season:
            return "{n}/Staffel {s.pad(2)}/{n} - {s00e00} - {t}"
        case .custom:
            return "{folder} - {index.pad(2)} - {original}"
        }
    }
}

public enum FileBotDatabase: String, CaseIterable, Identifiable, Codable {
    case themoviedb = "TheMovieDB::TV"
    case thetvdb = "TheTVDB"
    case anidb = "AniDB"
    case gemini = "Gemini::Plex"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .themoviedb: return "TheMovieDB (TMDb - Empfohlen)"
        case .thetvdb: return "TheTVDB (Serien-Archiv)"
        case .anidb: return "AniDB (Anime-Datenbank)"
        case .gemini: return "✨ Google Gemini KI (Plex-Optimiert)"
        }
    }
}

public enum FileBotLanguage: String, CaseIterable, Identifiable, Codable {
    case german = "German"
    case english = "English"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .german: return "Deutsch"
        case .english: return "Englisch"
        }
    }
}

public struct FileBotFormatPreset: Identifiable {
    public let id: String
    public let name: String
    public let format: String
    public let example: String
    public let mode: FileBotProcessingMode

    public static let seriesPresets: [FileBotFormatPreset] = [
        FileBotFormatPreset(
            id: "series-std",
            name: "Standard (S01E01)",
            format: "{n} - {s00e00} - {t}",
            example: "Breaking Bad - S01E01 - Der Einstieg.mp4",
            mode: .series
        ),
        FileBotFormatPreset(
            id: "series-compact",
            name: "Kompakt (1x01)",
            format: "{n} - {s}x{e.pad(2)} - {t}",
            example: "Breaking Bad - 1x01 - Der Einstieg.mp4",
            mode: .series
        ),
        FileBotFormatPreset(
            id: "series-minimal",
            name: "Nur Episode & Titel",
            format: "{s00e00} - {t}",
            example: "S01E01 - Der Einstieg.mp4",
            mode: .series
        ),
        FileBotFormatPreset(
            id: "series-year",
            name: "Mit Veröffentlichungsjahr",
            format: "{n} ({y}) - {s00e00} - {t}",
            example: "Breaking Bad (2008) - S01E01 - Der Einstieg.mp4",
            mode: .series
        )
    ]

    public static let seasonPresets: [FileBotFormatPreset] = [
        FileBotFormatPreset(
            id: "season-folder-de",
            name: "Staffel-Ordner (Deutsch)",
            format: "{n}/Staffel {s.pad(2)}/{n} - {s00e00} - {t}",
            example: "Breaking Bad/Staffel 01/Breaking Bad - S01E01 - Der Einstieg.mp4",
            mode: .season
        ),
        FileBotFormatPreset(
            id: "season-folder-en",
            name: "Season-Ordner (Englisch)",
            format: "{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}",
            example: "Breaking Bad/Season 01/Breaking Bad - S01E01 - Der Einstieg.mp4",
            mode: .season
        ),
        FileBotFormatPreset(
            id: "season-name-inline",
            name: "Staffel im Dateinamen",
            format: "{n} - Staffel {s} - Folge {e.pad(2)} - {t}",
            example: "Breaking Bad - Staffel 1 - Folge 01 - Der Einstieg.mp4",
            mode: .season
        )
    ]

    public static let customPresets: [FileBotFormatPreset] = [
        FileBotFormatPreset(
            id: "custom-folder-index-orig",
            name: "Ordner - Index - Original",
            format: "{folder} - {index.pad(2)} - {original}",
            example: "Urlaub 2024 - 01 - IMG_0042.jpg",
            mode: .custom
        ),
        FileBotFormatPreset(
            id: "custom-date-orig",
            name: "Datum - Original",
            format: "{date} - {original}",
            example: "2024-05-18 - Rechnung.pdf",
            mode: .custom
        ),
        FileBotFormatPreset(
            id: "custom-clean",
            name: "Bereinigt (Ohne Punkte/Unterstriche)",
            format: "{clean}",
            example: "Mein.Neuer.Film.1080p -> Mein Neuer Film",
            mode: .custom
        ),
        FileBotFormatPreset(
            id: "custom-date-folder-index",
            name: "Datum_Ordner_Index",
            format: "{date}_{folder}_{index.pad(3)}",
            example: "2024-05-18_Fotos_001.jpg",
            mode: .custom
        ),
        FileBotFormatPreset(
            id: "custom-index-original",
            name: "Index - Original",
            format: "{index.pad(2)} - {original}",
            example: "01 - Track 1.mp3",
            mode: .custom
        ),
        FileBotFormatPreset(
            id: "custom-lower",
            name: "Kleinbuchstaben",
            format: "{lower}",
            example: "Dokument_Final.PDF -> dokument_final.pdf",
            mode: .custom
        )
    ]
}

public enum FileCategoryFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case video = "video"
    case audio = "audio"
    case document = "document"
    case image = "image"
    case other = "other"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "Alle Dateien"
        case .video: return "Videos"
        case .audio: return "Audio"
        case .document: return "Dokumente"
        case .image: return "Bilder"
        case .other: return "Sonstige"
        }
    }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .video: return "film"
        case .audio: return "music.note"
        case .document: return "doc.text"
        case .image: return "photo"
        case .other: return "questionmark.folder"
        }
    }

    public func matches(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        switch self {
        case .all:
            return true
        case .video:
            let exts = ["mp4", "mkv", "mov", "avi", "webm", "m4v", "wmv", "flv", "ts", "mpg", "mpeg"]
            return exts.contains(ext)
        case .audio:
            let exts = ["mp3", "m4a", "flac", "wav", "aac", "ogg", "wma", "aiff", "opus"]
            return exts.contains(ext)
        case .document:
            let exts = ["pdf", "doc", "docx", "txt", "rtf", "odt", "xls", "xlsx", "csv", "ppt", "pptx", "md"]
            return exts.contains(ext)
        case .image:
            let exts = ["jpg", "jpeg", "png", "gif", "webp", "heic", "tiff", "tif", "bmp", "svg"]
            return exts.contains(ext)
        case .other:
            let known = ["mp4", "mkv", "mov", "avi", "webm", "m4v", "wmv", "flv", "ts", "mpg", "mpeg",
                         "mp3", "m4a", "flac", "wav", "aac", "ogg", "wma", "aiff", "opus",
                         "pdf", "doc", "docx", "txt", "rtf", "odt", "xls", "xlsx", "csv", "ppt", "pptx", "md",
                         "jpg", "jpeg", "png", "gif", "webp", "heic", "tiff", "tif", "bmp", "svg"]
            return !known.contains(ext)
        }
    }
}

public class FileBotRenameItem: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: UUID
    public let downloadItemId: UUID?
    public let originalURL: URL
    public let creationDate: Date?
    public let modificationDate: Date?
    public var relativeSourcePath: String?

    @Published public var isSelected: Bool = true
    @Published public var originalName: String
    @Published public var proposedName: String
    @Published public var proposedRelativePath: String
    @Published public var targetFolder: URL
    @Published public var seasonNumber: Int?
    @Published public var episodeNumber: Int?
    @Published public var seriesName: String?
    @Published public var isMatched: Bool = false
    @Published public var statusMessage: String = "Bereit"
    @Published public var isRenamed: Bool = false
    @Published public var isError: Bool = false

    public init(
        id: UUID = UUID(),
        downloadItemId: UUID? = nil,
        originalURL: URL,
        originalName: String? = nil,
        proposedName: String? = nil,
        proposedRelativePath: String? = nil,
        targetFolder: URL? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        seriesName: String? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        relativeSourcePath: String? = nil,
        isSelected: Bool = true
    ) {
        self.id = id
        self.downloadItemId = downloadItemId
        self.originalURL = originalURL
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.relativeSourcePath = relativeSourcePath
        self.isSelected = isSelected

        let name = originalName ?? originalURL.lastPathComponent
        self.originalName = name
        self.proposedName = proposedName ?? name
        self.proposedRelativePath = proposedRelativePath ?? name
        self.targetFolder = targetFolder ?? originalURL.deletingLastPathComponent()
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.seriesName = seriesName
    }

    public var proposedDestinationURL: URL {
        if proposedRelativePath.contains("/") {
            return targetFolder.appendingPathComponent(proposedRelativePath)
        } else {
            return targetFolder.appendingPathComponent(proposedName)
        }
    }

    public var isFolderChange: Bool {
        return proposedRelativePath.contains("/")
    }

    public var destinationSubfolderName: String? {
        guard proposedRelativePath.contains("/") else { return nil }
        let comps = proposedRelativePath.components(separatedBy: "/")
        if comps.count > 1 {
            return comps.dropLast().joined(separator: "/")
        }
        return nil
    }
}
