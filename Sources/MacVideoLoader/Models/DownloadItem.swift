import Foundation

public enum DownloadType: String, CaseIterable, Identifiable, Codable {
    case video = "video"
    case audio = "audio"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .video: return "Video (MP4)"
        case .audio: return "Nur Audio"
        }
    }

    public var icon: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .audio: return "waveform"
        }
    }
}

public enum VideoQuality: String, CaseIterable, Identifiable, Codable {
    case best = "best"
    case q2160p = "2160p"
    case q1440p = "1440p"
    case q1080p = "1080p"
    case q720p = "720p"
    case q480p = "480p"
    case q360p = "360p"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .best: return "Beste verfügbare Qualität (Bis 4K / 8K)"
        case .q2160p: return "4K Ultra HD (2160p)"
        case .q1440p: return "2K Quad HD (1440p)"
        case .q1080p: return "Full HD (1080p / Premium)"
        case .q720p: return "HD (720p)"
        case .q480p: return "SD (480p)"
        case .q360p: return "Kompakt (360p)"
        }
    }

    public var shortName: String {
        switch self {
        case .best: return "Max"
        case .q2160p: return "4K"
        case .q1440p: return "1440p"
        case .q1080p: return "1080p"
        case .q720p: return "720p"
        case .q480p: return "480p"
        case .q360p: return "360p"
        }
    }

    public var ytDlpFormatSelector: String {
        switch self {
        case .best:
            return "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[protocol^=http]/best"
        case .q2160p:
            return "bestvideo[height<=2160][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=2160]+bestaudio/best[height<=2160][protocol^=http]/best[height<=2160]/best"
        case .q1440p:
            return "bestvideo[height<=1440][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1440]+bestaudio/best[height<=1440][protocol^=http]/best[height<=1440]/best"
        case .q1080p:
            return "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080]+bestaudio/best[height<=1080][protocol^=http]/best[height<=1080]/best"
        case .q720p:
            return "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=720]+bestaudio/best[height<=720][protocol^=http]/best[height<=720]/best"
        case .q480p:
            return "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=480]+bestaudio/best[height<=480][protocol^=http]/best[height<=480]/best"
        case .q360p:
            return "bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=360]+bestaudio/best[height<=360][protocol^=http]/best[height<=360]/best"
        }
    }
}

public enum AudioFormat: String, CaseIterable, Identifiable, Codable {
    case mp3 = "mp3"
    case m4a = "m4a"
    case flac = "flac"
    case wav = "wav"
    case opus = "opus"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mp3: return "MP3 (320 kbps)"
        case .m4a: return "M4A / AAC (Apple Standard)"
        case .flac: return "FLAC (Verlustfrei)"
        case .wav: return "WAV (Studio/PCM)"
        case .opus: return "Opus (Web/Sprache)"
        }
    }

    public var shortName: String {
        rawValue.uppercased()
    }
}

public enum DownloadStatus: Equatable {
    case queued
    case fetchingInfo
    case downloading(progress: Double, speed: String, eta: String)
    case processing(stage: String)
    case paused
    case skipped
    case completed(filePath: URL)
    case failed(error: String)
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .skipped:
            return true
        default:
            return false
        }
    }

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    public var completedURL: URL? {
        if case .completed(let path) = self { return path }
        return nil
    }

    public var isActive: Bool {
        switch self {
        case .downloading, .fetchingInfo, .processing:
            return true
        default:
            return false
        }
    }

    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    public var isSkipped: Bool {
        if case .skipped = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    public var errorMessage: String? {
        if case .failed(let err) = self { return err }
        return nil
    }

    public var localizedDescription: String {
        switch self {
        case .queued:
            return "In Warteschlange"
        case .fetchingInfo:
            return "Lade Video-Informationen..."
        case .downloading(let progress, let speed, let eta):
            let pct = Int(progress * 100)
            return "\(pct)% • \(speed) • Noch \(eta)"
        case .processing(let stage):
            return stage
        case .paused:
            return "Pausiert"
        case .skipped:
            return "Übersprungen"
        case .completed:
            return "Fertiggestellt"
        case .failed(let error):
            return "Fehler: \(error)"
        case .cancelled:
            return "Abgebrochen"
        }
    }
}

public struct DownloadItemDTO: Codable, Sendable {
    public let id: UUID
    public let url: String
    public let title: String
    public let author: String
    public let duration: String
    public let thumbnailURL: String?
    public let downloadType: String
    public let videoQuality: String
    public let audioFormat: String
    public let destinationFolderPath: String
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let seasonTitle: String?
    public let seriesTitle: String?
    public let status: String
    public let progress: Double
    public let createdAt: Date
    public let completedFilePath: String?

    private enum CodingKeys: String, CodingKey {
        case id, url, title, author, duration, thumbnailURL
        case downloadType, videoQuality, audioFormat, destinationFolderPath
        case seasonNumber, episodeNumber, seasonTitle, seriesTitle
        case status, progress, createdAt, completedFilePath
    }

    public init(
        id: UUID,
        url: String,
        title: String,
        author: String,
        duration: String,
        thumbnailURL: String?,
        downloadType: String,
        videoQuality: String,
        audioFormat: String,
        destinationFolderPath: String,
        seasonNumber: Int?,
        episodeNumber: Int?,
        seasonTitle: String?,
        seriesTitle: String?,
        status: String,
        progress: Double,
        createdAt: Date,
        completedFilePath: String?
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.author = author
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.downloadType = downloadType
        self.videoQuality = videoQuality
        self.audioFormat = audioFormat
        self.destinationFolderPath = destinationFolderPath
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.seasonTitle = seasonTitle
        self.seriesTitle = seriesTitle
        self.status = status
        self.progress = progress
        self.createdAt = createdAt
        self.completedFilePath = completedFilePath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        self.url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? ""
        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Video wird vorbereitet..."
        self.author = (try? container.decodeIfPresent(String.self, forKey: .author)) ?? ""
        self.duration = (try? container.decodeIfPresent(String.self, forKey: .duration)) ?? ""
        self.thumbnailURL = try? container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        self.downloadType = (try? container.decodeIfPresent(String.self, forKey: .downloadType)) ?? "video"
        self.videoQuality = (try? container.decodeIfPresent(String.self, forKey: .videoQuality)) ?? "best"
        self.audioFormat = (try? container.decodeIfPresent(String.self, forKey: .audioFormat)) ?? "mp3"
        self.destinationFolderPath = (try? container.decodeIfPresent(String.self, forKey: .destinationFolderPath)) ?? ""
        self.seasonNumber = try? container.decodeIfPresent(Int.self, forKey: .seasonNumber)
        self.episodeNumber = try? container.decodeIfPresent(Int.self, forKey: .episodeNumber)
        self.seasonTitle = try? container.decodeIfPresent(String.self, forKey: .seasonTitle)
        self.seriesTitle = try? container.decodeIfPresent(String.self, forKey: .seriesTitle)
        self.status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? "queued"
        self.progress = (try? container.decodeIfPresent(Double.self, forKey: .progress)) ?? 0.0
        self.createdAt = (try? container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        self.completedFilePath = try? container.decodeIfPresent(String.self, forKey: .completedFilePath)
    }
}

public class DownloadItem: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: UUID
    public let url: String
    @Published public var title: String
    @Published public var author: String
    @Published public var duration: String
    @Published public var thumbnailURL: URL?
    public let downloadType: DownloadType
    public let videoQuality: VideoQuality
    public let audioFormat: AudioFormat
    public var destinationFolder: URL

    // Season & Series Metadata for Season-based actions (Skip Season, Folder Routing)
    public var seasonNumber: Int?
    public var episodeNumber: Int?
    public var seasonTitle: String?
    public var seriesTitle: String?

    // Auto-Retry state for systemic / network interruptions
    public var retryCount: Int = 0
    public var maxRetries: Int = 5

    @Published public var status: DownloadStatus = .queued
    @Published public var progress: Double = 0.0
    @Published public var speed: String = ""
    @Published public var eta: String = ""
    @Published public var completedFileURL: URL?

    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        url: String,
        title: String = "Video wird vorbereitet...",
        author: String = "",
        duration: String = "",
        thumbnailURL: URL? = nil,
        downloadType: DownloadType,
        videoQuality: VideoQuality = .best,
        audioFormat: AudioFormat = .mp3,
        destinationFolder: URL,
        status: DownloadStatus = .queued,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        seasonTitle: String? = nil,
        seriesTitle: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.author = author
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.downloadType = downloadType
        self.videoQuality = videoQuality
        self.audioFormat = audioFormat
        self.destinationFolder = destinationFolder
        self.status = status
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.seasonTitle = seasonTitle
        self.seriesTitle = seriesTitle
        self.createdAt = createdAt
    }

    public var formatBadgeText: String {
        if downloadType == .video {
            return "\(videoQuality.shortName) • MP4"
        } else {
            return "\(audioFormat.shortName)"
        }
    }

    public var isCompleted: Bool {
        return status.isCompleted
    }

    public func toDTO() -> DownloadItemDTO {
        let statusStr: String
        switch status {
        case .completed: statusStr = "completed"
        case .downloading: statusStr = "queued"
        case .processing: statusStr = "queued"
        case .fetchingInfo: statusStr = "queued"
        case .queued: statusStr = "queued"
        case .paused: statusStr = "paused"
        case .skipped: statusStr = "skipped"
        case .failed(let err): statusStr = "failed:\(err)"
        case .cancelled: statusStr = "cancelled"
        }

        return DownloadItemDTO(
            id: id,
            url: url,
            title: title,
            author: author,
            duration: duration,
            thumbnailURL: thumbnailURL?.absoluteString,
            downloadType: downloadType.rawValue,
            videoQuality: videoQuality.rawValue,
            audioFormat: audioFormat.rawValue,
            destinationFolderPath: destinationFolder.path,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            seasonTitle: seasonTitle,
            seriesTitle: seriesTitle,
            status: statusStr,
            progress: progress,
            createdAt: createdAt,
            completedFilePath: completedFileURL?.path
        )
    }

    public static func fromDTO(_ dto: DownloadItemDTO) -> DownloadItem {
        let dType = DownloadType(rawValue: dto.downloadType) ?? .video
        let vQuality = VideoQuality(rawValue: dto.videoQuality) ?? .best
        let aFormat = AudioFormat(rawValue: dto.audioFormat) ?? .mp3
        let dest = URL(fileURLWithPath: dto.destinationFolderPath)

        let initialStatus: DownloadStatus
        if dto.status == "completed" {
            if let path = dto.completedFilePath, FileManager.default.fileExists(atPath: path) {
                initialStatus = .completed(filePath: URL(fileURLWithPath: path))
            } else {
                initialStatus = .completed(filePath: dest)
            }
        } else if dto.status == "paused" {
            initialStatus = .paused
        } else if dto.status == "skipped" {
            initialStatus = .skipped
        } else if dto.status.hasPrefix("failed:") {
            let err = dto.status.replacingOccurrences(of: "failed:", with: "")
            initialStatus = .failed(error: err)
        } else if dto.status == "cancelled" {
            initialStatus = .cancelled
        } else {
            initialStatus = .queued
        }

        let item = DownloadItem(
            id: dto.id,
            url: dto.url,
            title: dto.title,
            author: dto.author,
            duration: dto.duration,
            thumbnailURL: dto.thumbnailURL.flatMap { URL(string: $0) },
            downloadType: dType,
            videoQuality: vQuality,
            audioFormat: aFormat,
            destinationFolder: dest,
            status: initialStatus,
            seasonNumber: dto.seasonNumber,
            episodeNumber: dto.episodeNumber,
            seasonTitle: dto.seasonTitle,
            seriesTitle: dto.seriesTitle,
            createdAt: dto.createdAt
        )
        item.progress = dto.progress
        if let path = dto.completedFilePath {
            item.completedFileURL = URL(fileURLWithPath: path)
        }
        return item
    }
}

extension DownloadItem: Equatable {
    public static func == (lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        lhs.id == rhs.id
    }
}
