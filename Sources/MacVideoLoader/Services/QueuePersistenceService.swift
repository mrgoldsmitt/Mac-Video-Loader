import Foundation

public final class QueuePersistenceService: @unchecked Sendable {
    public static let shared = QueuePersistenceService()

    private let lock = NSLock()
    private let appSupportURL: URL
    private let queueFileURL: URL

    private init() {
        let fileManager = FileManager.default
        let baseAppSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.appSupportURL = baseAppSupport.appendingPathComponent("Mac Video Loader", isDirectory: true)
        self.queueFileURL = self.appSupportURL.appendingPathComponent("queue.json")

        try? fileManager.createDirectory(at: self.appSupportURL, withIntermediateDirectories: true)
    }

    public func saveQueue(_ items: [DownloadItem]) {
        lock.lock()
        defer { lock.unlock() }

        let dtos = items.map { $0.toDTO() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(dtos)
            try data.write(to: queueFileURL, options: .atomic)
        } catch {
            print("Fehler beim Speichern der Warteschlange: \(error.localizedDescription)")
        }
    }

    public func loadQueue() -> [DownloadItem] {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: queueFileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: queueFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // 1. Try standard bulk decode
            if let dtos = try? decoder.decode([DownloadItemDTO].self, from: data) {
                return dtos.map { DownloadItem.fromDTO($0) }
            }

            // 2. Resilient fallback: decode element-by-element so one bad item never drops the rest of the queue
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var items: [DownloadItem] = []
                for dict in jsonArray {
                    if let itemData = try? JSONSerialization.data(withJSONObject: dict),
                       let dto = try? decoder.decode(DownloadItemDTO.self, from: itemData) {
                        items.append(DownloadItem.fromDTO(dto))
                    }
                }
                if !items.isEmpty {
                    return items
                }
            }

            return []
        } catch {
            print("Fehler beim Laden der Warteschlange: \(error.localizedDescription)")
            return []
        }
    }

    public func exportList(title: String, items: [DownloadItem], to url: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        let dtos = items.map { $0.toDTO() }
        let listFile = DownloadListFile(title: title, items: dtos)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(listFile)
        try data.write(to: url, options: .atomic)
    }

    public func importList(from url: URL) throws -> [DownloadItem] {
        lock.lock()
        defer { lock.unlock() }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let listFile = try? decoder.decode(DownloadListFile.self, from: data) {
            return listFile.items.map { DownloadItem.fromDTO($0) }
        } else if let dtos = try? decoder.decode([DownloadItemDTO].self, from: data) {
            return dtos.map { DownloadItem.fromDTO($0) }
        } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var items: [DownloadItem] = []
            for dict in jsonArray {
                if let itemData = try? JSONSerialization.data(withJSONObject: dict),
                   let dto = try? decoder.decode(DownloadItemDTO.self, from: itemData) {
                    items.append(DownloadItem.fromDTO(dto))
                }
            }
            return items
        }
        return []
    }
}
