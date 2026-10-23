import Foundation

public struct PlaylistItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let url: String
    public let title: String
    public let duration: String?
    public let thumbnailURL: URL?
    public let uploader: String?
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let seasonTitle: String?

    public init(
        id: String,
        url: String,
        title: String,
        duration: String? = nil,
        thumbnailURL: URL? = nil,
        uploader: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        seasonTitle: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.uploader = uploader
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.seasonTitle = seasonTitle
    }
}

public struct PlaylistInfo: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let extractor: String
    public let items: [PlaylistItem]
    public let initialSelectedUrl: String?
    public let seriesName: String?

    public var isPlaylist: Bool {
        return items.count > 1
    }

    public var isSeasonOrSeries: Bool {
        let ext = extractor.lowercased()
        if ext.contains("ard") || ext.contains("zdf") || ext.contains("arte") {
            return true
        }
        return items.contains(where: { $0.seasonNumber != nil || $0.seasonTitle != nil })
    }

    public var effectiveSeriesTitle: String {
        if let s = seriesName?.trimmingCharacters(in: .whitespaces), !s.isEmpty {
            return s
        }
        let separators = [" – ", " - ", " | "]
        for sep in separators {
            if title.contains(sep) {
                let parts = title.components(separatedBy: sep)
                if parts.count >= 2 {
                    let last = parts.last?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
                    if last.hasPrefix("staffel") || last.hasPrefix("season") {
                        let name = parts.dropLast().joined(separator: sep).trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty { return name }
                    }
                }
            }
        }
        return title
    }

    public func targetFolder(for item: PlaylistItem, baseFolder: URL) -> URL {
        if isSeasonOrSeries {
            let sanitizedSeries = Self.sanitizeFolderName(effectiveSeriesTitle)
            let seriesFolder = baseFolder.appendingPathComponent(sanitizedSeries, isDirectory: true)

            let seasonName: String? = {
                if let st = item.seasonTitle?.trimmingCharacters(in: .whitespaces), !st.isEmpty {
                    return st
                } else if let sNum = item.seasonNumber {
                    return "Staffel \(sNum)"
                }
                return nil
            }()

            if let sName = seasonName {
                let sanitizedSeason = Self.sanitizeFolderName(sName)
                return seriesFolder.appendingPathComponent(sanitizedSeason, isDirectory: true)
            }
            return seriesFolder
        } else {
            let sanitizedPlaylist = Self.sanitizeFolderName(title)
            return baseFolder.appendingPathComponent(sanitizedPlaylist, isDirectory: true)
        }
    }

    public static func sanitizeFolderName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: #":/\?%*|"<>~"#)
            .union(.newlines)
            .union(.controlCharacters)
        var cleaned = name.components(separatedBy: invalidCharacters).joined(separator: " ")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return "Unbenannter Ordner"
        }
        if cleaned.hasPrefix(".") {
            cleaned = "_" + cleaned.dropFirst()
        }
        if cleaned.count > 100 {
            cleaned = String(cleaned.prefix(100)).trimmingCharacters(in: .whitespaces)
        }
        return cleaned
    }

    public var detectedSeasons: [String] {
        var seasonsSet = Set<String>()
        var list: [String] = []
        for item in items {
            if let st = item.seasonTitle, !st.isEmpty {
                if !seasonsSet.contains(st) {
                    seasonsSet.insert(st)
                    list.append(st)
                }
            }
        }
        return list.sorted { s1, s2 in
            let n1 = Int(s1.replacingOccurrences(of: "Staffel ", with: "").trimmingCharacters(in: .whitespaces)) ?? 999
            let n2 = Int(s2.replacingOccurrences(of: "Staffel ", with: "").trimmingCharacters(in: .whitespaces)) ?? 999
            return n1 < n2
        }
    }

    public init(
        id: String,
        title: String,
        extractor: String = "",
        items: [PlaylistItem],
        initialSelectedUrl: String? = nil,
        seriesName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.extractor = extractor
        self.items = items
        self.initialSelectedUrl = initialSelectedUrl
        self.seriesName = seriesName
    }
}

public enum URLInspectionResult: Sendable {
    case singleVideo(VideoMetadata)
    case playlist(PlaylistInfo)
}
