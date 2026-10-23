import Foundation

public struct DownloadListFile: Codable, Sendable {
    public static let currentVersion = "1.0"
    public static let fileExtension = "mvl"

    public let version: String
    public let title: String
    public let createdAt: Date
    public let items: [DownloadItemDTO]

    public init(title: String, items: [DownloadItemDTO]) {
        self.version = Self.currentVersion
        self.title = title
        self.createdAt = Date()
        self.items = items
    }
}
