import Foundation
import AppKit

public struct VideoMetadata: Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let duration: String
    public let thumbnailURL: URL?

    public init(id: String, title: String, author: String = "", duration: String = "", thumbnailURL: URL? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.thumbnailURL = thumbnailURL
    }
}

private final class InspectionContext: @unchecked Sendable {
    private let lock = NSLock()
    private var lineBuffer = Data()
    private(set) var parsedItems: [PlaylistItem] = []
    private(set) var detectedPlaylistTitle: String = ""
    private(set) var detectedPlaylistId: String = ""
    private(set) var detectedExtractor: String = ""
    private(set) var detectedTotalCount: Int? = nil
    private(set) var singleVideoMeta: VideoMetadata? = nil
    private(set) var detectedSeriesName: String = ""

    func processIncomingData(_ data: Data, originalURL: String, onProgress: (@Sendable (Double, String, Int, Int?) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }

        lineBuffer.append(data)

        while let newlineIdx = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = lineBuffer.prefix(upTo: newlineIdx)
            lineBuffer.removeSubrange(...newlineIdx)

            guard !lineData.isEmpty else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            parseEntry(json: json, originalURL: originalURL, onProgress: onProgress)
        }
    }

    func flushBuffer(originalURL: String) {
        lock.lock()
        defer { lock.unlock() }

        guard !lineBuffer.isEmpty else { return }
        if let json = try? JSONSerialization.jsonObject(with: lineBuffer) as? [String: Any] {
            parseEntry(json: json, originalURL: originalURL, onProgress: nil)
        }
        lineBuffer.removeAll()
    }

    private func parseEntry(json: [String: Any], originalURL: String, onProgress: (@Sendable (Double, String, Int, Int?) -> Void)?) {
        let rawType = json["_type"] as? String ?? ""
        let extractor = json["extractor_key"] as? String ?? (json["extractor"] as? String ?? "")
        let pTitle = json["playlist_title"] as? String ?? (json["playlist"] as? String ?? "")
        let pId = json["playlist_id"] as? String ?? ""
        let pCount = json["playlist_count"] as? Int ?? (json["n_entries"] as? Int)
        let series = json["series"] as? String ?? ""

        if !series.isEmpty && detectedSeriesName.isEmpty {
            detectedSeriesName = series
        }

        if !pTitle.isEmpty && detectedPlaylistTitle.isEmpty {
            detectedPlaylistTitle = pTitle
        }
        if !pId.isEmpty && detectedPlaylistId.isEmpty {
            detectedPlaylistId = pId
        }
        if !extractor.isEmpty && detectedExtractor.isEmpty {
            detectedExtractor = extractor
        }
        if let c = pCount, c > 0 {
            detectedTotalCount = c
        }

        let id = json["id"] as? String ?? "\(parsedItems.count)"
        let title = json["title"] as? String ?? "Video #\(parsedItems.count + 1)"
        let uploader = json["uploader"] as? String ?? (json["channel"] as? String)

        // Try extracting series name from title if still empty (e.g. "... | Babylon Berlin ...")
        if detectedSeriesName.isEmpty && title.contains(" | ") {
            let parts = title.components(separatedBy: " | ")
            if parts.count > 1, let afterBar = parts.last {
                let cleaned = afterBar.components(separatedBy: " (").first?.trimmingCharacters(in: .whitespaces) ?? ""
                if !cleaned.isEmpty {
                    detectedSeriesName = cleaned
                }
            }
        }

        var durationStr: String? = nil
        if let durSec = json["duration"] as? Double {
            durationStr = YTDlpService.formatDuration(seconds: Int(durSec))
        } else if let durS = json["duration_string"] as? String {
            durationStr = durS
        }

        var thumbURL: URL? = nil
        if let thumbs = json["thumbnails"] as? [[String: Any]], let last = thumbs.last, let u = last["url"] as? String {
            thumbURL = URL(string: u)
        } else if let tStr = json["thumbnail"] as? String {
            thumbURL = URL(string: tStr)
        }
        if thumbURL == nil, extractor.lowercased().contains("youtube"), !id.isEmpty {
            thumbURL = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
        }

        var itemURL = json["url"] as? String ?? ""
        if !itemURL.hasPrefix("http") {
            if let webURL = json["webpage_url"] as? String, webURL.hasPrefix("http") {
                itemURL = webURL
            } else if extractor.lowercased().contains("youtube") && !id.isEmpty {
                itemURL = "https://www.youtube.com/watch?v=\(id)"
            } else if !originalURL.isEmpty {
                itemURL = originalURL
            }
        }

        // Season & Episode detection
        let sNum = json["season_number"] as? Int
        let eNum = json["episode_number"] as? Int
        let sStr = json["season"] as? String
        let seInfo = YTDlpService.parseSeasonEpisode(
            title: title,
            jsonSeasonNum: sNum,
            jsonEpisodeNum: eNum,
            jsonSeasonStr: sStr
        )

        if (rawType == "video" || rawType.isEmpty) && pCount == nil && pTitle.isEmpty && parsedItems.isEmpty {
            singleVideoMeta = VideoMetadata(
                id: id,
                title: title,
                author: uploader ?? "",
                duration: durationStr ?? "",
                thumbnailURL: thumbURL
            )
        }

        let item = PlaylistItem(
            id: id,
            url: itemURL,
            title: title,
            duration: durationStr,
            thumbnailURL: thumbURL,
            uploader: uploader,
            seasonNumber: seInfo.seasonNumber,
            episodeNumber: seInfo.episodeNumber,
            seasonTitle: seInfo.seasonTitle
        )
        parsedItems.append(item)

        let countSoFar = parsedItems.count
        if let total = detectedTotalCount, total > 0 {
            let frac = min(0.98, max(0.08, Double(countSoFar) / Double(total)))
            onProgress?(frac, "Video \(countSoFar) von \(total): \(title)", countSoFar, total)
        } else {
            let frac = min(0.95, 0.08 + Double(countSoFar) * 0.04)
            onProgress?(frac, "Titel #\(countSoFar) erfasst: \(title)", countSoFar, nil)
        }
    }

    func buildResult(initialSelectedUrl: String? = nil) -> URLInspectionResult? {
        lock.lock()
        defer { lock.unlock() }

        if parsedItems.count > 1 || (!detectedPlaylistTitle.isEmpty && !parsedItems.isEmpty) {
            var finalTitle = detectedPlaylistTitle.isEmpty ? (parsedItems.first?.title ?? "Playlist") : detectedPlaylistTitle
            if (finalTitle.lowercased().hasPrefix("staffel ") || finalTitle.lowercased().hasPrefix("season ")) && !detectedSeriesName.isEmpty {
                finalTitle = "\(detectedSeriesName) – \(finalTitle)"
            }

            return .playlist(PlaylistInfo(
                id: detectedPlaylistId.isEmpty ? UUID().uuidString : detectedPlaylistId,
                title: finalTitle,
                extractor: detectedExtractor,
                items: parsedItems,
                initialSelectedUrl: initialSelectedUrl,
                seriesName: detectedSeriesName.isEmpty ? nil : detectedSeriesName
            ))
        } else if let single = singleVideoMeta ?? parsedItems.first.map({ VideoMetadata(id: $0.id, title: $0.title, author: $0.uploader ?? "", duration: $0.duration ?? "", thumbnailURL: $0.thumbnailURL) }) {
            return .singleVideo(single)
        }
        return nil
    }

    var totalItemsCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return parsedItems.count
    }
}

public final class YTDlpService: @unchecked Sendable {
    public static let shared = YTDlpService()

    private var activeProcesses: [UUID: Process] = [:]
    private var activeInspectionProcess: Process?
    private var isInspectionCancelled: Bool = false
    private let lock = NSLock()

    private init() {}

    public func cancelInspection() {
        lock.lock()
        defer { lock.unlock() }
        isInspectionCancelled = true
        if let proc = activeInspectionProcess {
            proc.terminate()
            activeInspectionProcess = nil
        }
    }

    private func resetInspectionState() {
        lock.lock()
        defer { lock.unlock() }
        isInspectionCancelled = false
        activeInspectionProcess = nil
    }

    private func registerInspectionProcess(_ process: Process) {
        lock.lock()
        defer { lock.unlock() }
        activeInspectionProcess = process
    }

    private func checkAndClearInspectionProcess() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        activeInspectionProcess = nil
        return isInspectionCancelled
    }

    public static func parseSeasonEpisode(
        title: String,
        jsonSeasonNum: Int?,
        jsonEpisodeNum: Int?,
        jsonSeasonStr: String?
    ) -> (seasonNumber: Int?, episodeNumber: Int?, seasonTitle: String?) {
        var sNum = jsonSeasonNum
        var eNum = jsonEpisodeNum
        var sTitle = jsonSeasonStr

        // 1. Try S01/E01 or S01E01
        if sNum == nil || eNum == nil {
            let pattern = #"[Ss](\d+)[\s/._-]*[Ee](\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
                if let r1 = Range(match.range(at: 1), in: title), let n1 = Int(title[r1]) {
                    sNum = sNum ?? n1
                }
                if let r2 = Range(match.range(at: 2), in: title), let n2 = Int(title[r2]) {
                    eNum = eNum ?? n2
                }
            }
        }

        // 2. Try "Staffel X" or "Season X"
        if sNum == nil {
            let pattern = #"(?:Staffel|Season)\s*(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
                if let r = Range(match.range(at: 1), in: title), let n = Int(title[r]) {
                    sNum = n
                }
            }
        }

        // 3. Try "Folge X" or "Episode X" or "(X/Y)"
        if eNum == nil {
            let pattern = #"(?:Folge|Episode|Teil)\s*(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
                if let r = Range(match.range(at: 1), in: title), let n = Int(title[r]) {
                    eNum = n
                }
            } else {
                let slashPattern = #"\b(\d+)\s*/\s*\d+\b"#
                if let regex = try? NSRegularExpression(pattern: slashPattern),
                   let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
                    if let r = Range(match.range(at: 1), in: title), let n = Int(title[r]) {
                        eNum = n
                    }
                }
            }
        }

        if let s = sNum {
            sTitle = "Staffel \(s)"
        } else if let st = sTitle, st.lowercased().hasPrefix("season ") {
            let numStr = st.replacingOccurrences(of: "season ", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            if let num = Int(numStr) {
                sNum = num
                sTitle = "Staffel \(num)"
            }
        }

        return (sNum, eNum, sTitle)
    }

    public static func resolveMediathekSeasonURL(from urlString: String) async -> String? {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else { return nil }

        // 1. ARD Mediathek
        if host.contains("ardmediathek.de") {
            if url.path.contains("/serie/") || url.path.contains("/sammlung/") {
                return nil
            }
            if url.path.contains("/video/") {
                guard let html = try? await fetchHTML(from: url) else { return nil }
                let pattern = #"href=["'](/serie/[a-zA-Z0-9\-_/]+)["']"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html) {
                    let path = String(html[range])
                    return "https://www.ardmediathek.de\(path)"
                }
            }
        }

        // 2. ZDF Mediathek
        if host.contains("zdf.de") {
            if !url.path.contains("/video/") {
                return nil
            }
            if let html = try? await fetchHTML(from: url) {
                let pattern = #"href=["'](/(?:serien|animation|kinder|dokumentation|filme|shows)/[a-zA-Z0-9\-_]+)["']"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html) {
                    let path = String(html[range])
                    return "https://www.zdf.de\(path)"
                }
            }

            // Fallback: derive parent collection URL by stripping /video/ and the last episode component
            let components = url.pathComponents.filter { $0 != "/" }
            if components.count >= 3 && components[0] == "video" {
                let parentComponents = components.dropFirst().dropLast()
                let parentPath = "/" + parentComponents.joined(separator: "/")
                return "https://www.zdf.de\(parentPath)"
            }
        }

        // 3. Arte
        if host.contains("arte.tv") {
            if url.path.contains("/RC-") {
                return nil
            }
            guard let html = try? await fetchHTML(from: url) else { return nil }
            let pattern = #"href=["'](/de/videos/RC-[a-zA-Z0-9\-_/]+)["']"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let path = String(html[range])
                return "https://www.arte.tv\(path)"
            }
        }

        return nil
    }

    private static func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(decoding: data, as: UTF8.self)
    }

    public func inspectURL(
        url: String,
        settings: AppSettings,
        onProgress: (@Sendable (Double, String, Int, Int?) -> Void)? = nil
    ) async throws -> URLInspectionResult {
        do {
            return try await internalInspectWithResolution(
                url: url,
                settings: settings,
                allowCookies: settings.useCookies,
                onProgress: onProgress
            )
        } catch {
            if error is CancellationError { throw error }
            if settings.useCookies {
                // If inspection failed while cookies were enabled (e.g. macOS TCC permission blockade or bad cookies),
                // automatically retry without cookies.
                return try await internalInspectWithResolution(
                    url: url,
                    settings: settings,
                    allowCookies: false,
                    onProgress: onProgress
                )
            }
            throw error
        }
    }

    private func internalInspectWithResolution(
        url: String,
        settings: AppSettings,
        allowCookies: Bool,
        onProgress: (@Sendable (Double, String, Int, Int?) -> Void)? = nil
    ) async throws -> URLInspectionResult {
        // If this URL is a single episode of ARD, ZDF, or Arte, attempt to resolve the parent Staffel/Series first
        if let seasonURL = await Self.resolveMediathekSeasonURL(from: url) {
            onProgress?(0.03, "Mediathek-Staffel erkannt! Rufe alle Episoden ab...", 0, nil)
            do {
                let seasonResult = try await internalInspectURL(
                    url: seasonURL,
                    originalRequestURL: url,
                    settings: settings,
                    allowCookies: allowCookies,
                    onProgress: onProgress
                )
                if case .playlist = seasonResult {
                    return seasonResult
                }
            } catch {
                if error is CancellationError { throw error }
                // If season inspection fails, gracefully proceed with single episode inspection
            }
        }

        return try await internalInspectURL(
            url: url,
            originalRequestURL: nil,
            settings: settings,
            allowCookies: allowCookies,
            onProgress: onProgress
        )
    }

    private func internalInspectURL(
        url: String,
        originalRequestURL: String?,
        settings: AppSettings,
        allowCookies: Bool,
        onProgress: (@Sendable (Double, String, Int, Int?) -> Void)? = nil
    ) async throws -> URLInspectionResult {
        guard let ytDlp = SystemService.shared.findYtDlp(customPath: settings.customYtDlpPath) else {
            throw NSError(domain: "MacVideoLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "yt-dlp Engine wurde nicht gefunden."])
        }

        resetInspectionState()

        var arguments = [
            "--dump-json",
            "--flat-playlist",
            "--yes-playlist",
            "--playlist-end", "500",
            "--no-warnings",
            "--socket-timeout", "20"
        ]

        appendEngineFlags(arguments: &arguments, settings: settings, allowCookies: allowCookies)
        arguments.append(url)

        onProgress?(0.05, "Verbinde mit Webseite & rufe Inhaltsstruktur ab...", 0, nil)

        let context = InspectionContext()

        final class StderrCollector: @unchecked Sendable {
            private let lock = NSLock()
            private var _text = ""
            var text: String {
                lock.lock()
                defer { lock.unlock() }
                return _text
            }
            func append(_ s: String) {
                lock.lock()
                defer { lock.unlock() }
                _text += s
            }
        }
        let stderrCollector = StderrCollector()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlp)
            process.arguments = arguments
            process.environment = buildEnvironment()

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            self.registerInspectionProcess(process)

            stdoutPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let availableData = fileHandle.availableData
                guard !availableData.isEmpty else { return }
                context.processIncomingData(availableData, originalURL: url, onProgress: onProgress)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let availableData = fileHandle.availableData
                guard !availableData.isEmpty, let text = String(data: availableData, encoding: .utf8) else { return }
                stderrCollector.append(text)
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                _ = self.checkAndClearInspectionProcess()
                continuation.resume(throwing: error)
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                // Drain remaining data from pipes
                let remainingOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingOut.isEmpty {
                    context.processIncomingData(remainingOut, originalURL: url, onProgress: onProgress)
                }
                let remainingErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingErr.isEmpty, let text = String(data: remainingErr, encoding: .utf8) {
                    stderrCollector.append(text)
                }

                let wasCancelled = self.checkAndClearInspectionProcess()

                context.flushBuffer(originalURL: url)

                if wasCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                if process.terminationStatus == 0 {
                    if let result = context.buildResult(initialSelectedUrl: originalRequestURL) {
                        let count = context.totalItemsCount
                        onProgress?(1.0, "\(count) Videos erfasst", count, count)
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "MacVideoLoader",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Keine Video- oder Playlist-Inhalte auf der Webseite gefunden."]
                        ))
                    }
                } else {
                    let errText = stderrCollector.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: NSError(
                        domain: "MacVideoLoader",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: errText.isEmpty ? "Fehler beim Analysieren der URL." : errText]
                    ))
                }
            }
        }
    }

    public func fetchMetadata(url: String, settings: AppSettings) async throws -> VideoMetadata {
        do {
            return try await internalFetchMetadata(url: url, settings: settings, allowCookies: settings.useCookies)
        } catch {
            let errStr = error.localizedDescription
            if settings.useCookies && isCookiePermissionError(errStr) {
                return try await internalFetchMetadata(url: url, settings: settings, allowCookies: false)
            }
            throw error
        }
    }

    private func internalFetchMetadata(url: String, settings: AppSettings, allowCookies: Bool) async throws -> VideoMetadata {
        guard let ytDlp = SystemService.shared.findYtDlp(customPath: settings.customYtDlpPath) else {
            throw NSError(domain: "MacVideoLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "yt-dlp Engine wurde nicht gefunden."])
        }

        var arguments = [
            "--no-playlist",
            "--no-warnings",
            "--print", "%(id)s|%(title)s|%(uploader)s|%(duration_string)s|%(thumbnail)s"
        ]

        appendEngineFlags(arguments: &arguments, settings: settings, allowCookies: allowCookies)
        arguments.append(url)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlp)
            process.arguments = arguments
            process.environment = buildEnvironment()

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !output.isEmpty else {
                        continuation.resume(throwing: NSError(domain: "MacVideoLoader", code: 2, userInfo: [NSLocalizedDescriptionKey: "Keine Video-Daten empfangen."]))
                        return
                    }

                    let lines = output.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    guard let targetLine = lines.last else {
                        continuation.resume(throwing: NSError(domain: "MacVideoLoader", code: 2, userInfo: [NSLocalizedDescriptionKey: "Ungültige Video-Informationen."]))
                        return
                    }

                    let parts = targetLine.components(separatedBy: "|")
                    let vidId = parts.count > 0 ? parts[0] : ""
                    let title = parts.count > 1 ? parts[1] : "Unbenanntes Video"
                    let author = parts.count > 2 ? parts[2] : ""
                    let duration = parts.count > 3 ? parts[3] : ""
                    let thumbStr = parts.count > 4 ? parts[4] : ""
                    let thumbURL = URL(string: thumbStr)

                    let meta = VideoMetadata(
                        id: vidId,
                        title: title,
                        author: author,
                        duration: duration,
                        thumbnailURL: thumbURL
                    )
                    continuation.resume(returning: meta)
                } else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unbekannter Fehler"
                    continuation.resume(throwing: NSError(domain: "MacVideoLoader", code: 3, userInfo: [NSLocalizedDescriptionKey: errText]))
                }
            }
        }
    }

    public func download(
        item: DownloadItem,
        settings: AppSettings,
        onProgress: @escaping (Double, String, String) -> Void,
        onStageChange: @escaping (String) -> Void
    ) async throws -> URL {
        do {
            return try await internalDownload(item: item, settings: settings, allowCookies: settings.useCookies, onProgress: onProgress, onStageChange: onStageChange)
        } catch {
            let errStr = error.localizedDescription
            if settings.useCookies && isCookiePermissionError(errStr) {
                let browserName = settings.selectedBrowser.displayName
                DispatchQueue.main.async {
                    onStageChange("\(browserName)-Cookies blockiert (macOS-Schutz). Lade ohne Account...")
                }
                do {
                    return try await internalDownload(item: item, settings: settings, allowCookies: false, onProgress: onProgress, onStageChange: onStageChange)
                } catch {
                    if isAgeOrSignInRequired(error.localizedDescription) {
                        throw NSError(domain: "MacVideoLoader", code: 403, userInfo: [
                            NSLocalizedDescriptionKey: "Dieses Video erfordert eine Anmeldung. Erteile Mac Video Loader in den macOS-Systemeinstellungen 'Festplattenvollzugriff' oder wähle eine cookies.txt."
                        ])
                    }
                    throw error
                }
            }
            throw error
        }
    }

    private func internalDownload(
        item: DownloadItem,
        settings: AppSettings,
        allowCookies: Bool,
        onProgress: @escaping (Double, String, String) -> Void,
        onStageChange: @escaping (String) -> Void
    ) async throws -> URL {
        guard let ytDlp = SystemService.shared.findYtDlp(customPath: settings.customYtDlpPath) else {
            throw NSError(domain: "MacVideoLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "yt-dlp Engine wurde nicht gefunden."])
        }

        guard let ffmpeg = SystemService.shared.findFfmpeg(customPath: settings.customFfmpegPath) else {
            throw NSError(domain: "MacVideoLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "FFmpeg wurde nicht gefunden. Bitte installiere FFmpeg."])
        }

        try? FileManager.default.createDirectory(at: item.destinationFolder, withIntermediateDirectories: true)

        let pathLogFile = FileManager.default.temporaryDirectory.appendingPathComponent("mvl_path_\(UUID().uuidString).txt")

        var arguments: [String] = [
            "--no-playlist",
            "--newline",
            "--no-colors",
            "--continue",
            "--retries", "10",
            "--fragment-retries", "10",
            "--retry-sleep", "exp=1:5:60",
            "--file-access-retries", "5",
            "--socket-timeout", "30",
            "--concurrent-fragments", "4",
            "--postprocessor-args", "ffmpeg:-nostdin -threads 0 -y",
            "--ffmpeg-location", ffmpeg,
            "--print-to-file", "after_move:filepath", pathLogFile.path,
            "--progress-template", "[download] %(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s"
        ]

        appendEngineFlags(arguments: &arguments, settings: settings, allowCookies: allowCookies)

        if item.downloadType == .video {
            arguments.append(contentsOf: [
                "-f", item.videoQuality.ytDlpFormatSelector,
                "--merge-output-format", "mp4"
            ])
        } else {
            arguments.append(contentsOf: [
                "-x",
                "--audio-format", item.audioFormat.rawValue,
                "--audio-quality", "0"
            ])
        }

        let outputTemplate = "\(item.destinationFolder.path)/%(title)s [%(id)s].%(ext)s"
        arguments.append(contentsOf: ["-o", outputTemplate])
        arguments.append(item.url)

        final class DownloadRunState: @unchecked Sendable {
            private let lock = NSLock()
            private var _destinationPath: String? = nil
            private var _lastError: String = ""

            var destinationPath: String? {
                get { lock.lock(); defer { lock.unlock() }; return _destinationPath }
                set { lock.lock(); defer { lock.unlock() }; _destinationPath = newValue }
            }

            var lastError: String {
                get { lock.lock(); defer { lock.unlock() }; return _lastError }
            }

            func appendError(_ text: String) {
                lock.lock()
                defer { lock.unlock() }
                _lastError += text
                if _lastError.count > 8192 {
                    _lastError = String(_lastError.suffix(8192))
                }
            }
        }

        let runState = DownloadRunState()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlp)
            process.arguments = arguments
            process.environment = buildEnvironment()
            process.standardInput = FileHandle.nullDevice

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            lock.lock()
            activeProcesses[item.id] = process
            lock.unlock()

            let outHandle = stdoutPipe.fileHandleForReading
            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

                let lines = text.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }

                    if trimmed.hasPrefix("[download]") && trimmed.contains("|") {
                        let clean = trimmed.replacingOccurrences(of: "[download]", with: "").trimmingCharacters(in: .whitespaces)
                        let components = clean.components(separatedBy: "|")
                        if components.count >= 3 {
                            let pctStr = components[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                            let speed = components[1].trimmingCharacters(in: .whitespaces)
                            let eta = components[2].trimmingCharacters(in: .whitespaces)

                            if let pctVal = Double(pctStr) {
                                DispatchQueue.main.async {
                                    onProgress(pctVal / 100.0, speed.isEmpty || speed == "NA" ? "..." : speed, eta.isEmpty || eta == "NA" ? "..." : eta)
                                }
                            }
                        }
                    } else if trimmed.contains("[download] Destination:") {
                        let path = trimmed.replacingOccurrences(of: "[download] Destination:", with: "").trimmingCharacters(in: .whitespaces)
                        runState.destinationPath = path
                    } else if trimmed.contains("[Merger]") || trimmed.contains("Merging formats") {
                        DispatchQueue.main.async {
                            onStageChange("Füge Video & Audio zusammen (MP4)...")
                        }
                    } else if trimmed.contains("[ExtractAudio]") {
                        DispatchQueue.main.async {
                            onStageChange("Konvertiere Tonspur (\(item.audioFormat.shortName))...")
                        }
                    } else if trimmed.contains("[Fixup") {
                        DispatchQueue.main.async {
                            onStageChange("Optimiere Container...")
                        }
                    }
                }
            }

            let errHandle = stderrPipe.fileHandleForReading
            errHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                runState.appendError(text)
            }

            do {
                try process.run()
            } catch {
                self.cleanupProcess(item.id)
                continuation.resume(throwing: error)
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                outHandle.readabilityHandler = nil
                errHandle.readabilityHandler = nil
                self.cleanupProcess(item.id)

                if process.terminationStatus == 0 {
                    var finalURL: URL? = nil

                    // 1. Check exact output path written to pathLogFile
                    if FileManager.default.fileExists(atPath: pathLogFile.path),
                       let savedPath = try? String(contentsOf: pathLogFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                       !savedPath.isEmpty, FileManager.default.fileExists(atPath: savedPath) {
                        finalURL = URL(fileURLWithPath: savedPath)
                        try? FileManager.default.removeItem(at: pathLogFile)
                    }

                    // 2. Fallback to destinationPath parsed from stdout
                    if finalURL == nil, let path = runState.destinationPath {
                        let candidate = URL(fileURLWithPath: path)
                        if FileManager.default.fileExists(atPath: candidate.path) {
                            finalURL = candidate
                        }
                    }

                    // 3. Fallback to latest file in folder
                    if finalURL == nil {
                        if let files = try? FileManager.default.contentsOfDirectory(at: item.destinationFolder, includingPropertiesForKeys: [.contentModificationDateKey]) {
                            finalURL = files.sorted(by: { f1, f2 in
                                let d1 = (try? f1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                                let d2 = (try? f2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                                return d1 > d2
                            }).first
                        }
                    }

                    continuation.resume(returning: finalURL ?? item.destinationFolder)
                } else {
                    try? FileManager.default.removeItem(at: pathLogFile)
                    let errMsg = runState.lastError.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: NSError(
                        domain: "MacVideoLoader",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: errMsg.isEmpty ? "Download fehlgeschlagen." : errMsg]
                    ))
                }
            }
        }
    }

    public func testBrowserCookies(browser: SupportedBrowser, customPath: String = "") async -> (success: Bool, message: String) {
        guard let ytDlp = SystemService.shared.findYtDlp() else {
            return (false, "yt-dlp Engine wurde nicht gefunden.")
        }

        var arguments = [
            "--no-playlist",
            "--no-warnings"
        ]

        appendEngineFlags(arguments: &arguments, settings: AppSettings.shared, allowCookies: false)

        if browser == .customFile {
            let expanded = NSString(string: customPath).expandingTildeInPath
            if customPath.isEmpty {
                return (false, "Bitte wähle den Pfad zu deiner cookies.txt Datei aus.")
            }
            if !FileManager.default.fileExists(atPath: expanded) {
                return (false, "Die Datei wurde unter '\(customPath)' nicht gefunden.")
            }
            arguments.append(contentsOf: ["--cookies", expanded])
        } else {
            arguments.append(contentsOf: ["--cookies-from-browser", browser.rawValue])
        }

        arguments.append(contentsOf: ["--print", "%(id)s", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"])

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlp)
        process.arguments = arguments
        process.environment = buildEnvironment()

        let errPipe = Pipe()
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return (true, "Cookies von \(browser.displayName) erfolgreich erkannt und Zugriff verifiziert!")
            } else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errText = String(data: errData, encoding: .utf8) ?? ""
                if errText.contains("Operation not permitted") {
                    return (false, "macOS verweigert den Zugriff auf \(browser.displayName)-Dateien. Bitte aktiviere in den macOS-Systemeinstellungen den Schalter bei 'Mac Video Loader'.")
                } else if errText.contains("could not find") && errText.contains("cookies database") {
                    return (false, "Keine Cookie-Datenbank für \(browser.displayName) gefunden. Bist du in diesem Browser angemeldet?")
                } else {
                    let cleanMsg = errText.components(separatedBy: .newlines).first(where: { $0.hasPrefix("ERROR:") }) ?? errText
                    return (false, cleanMsg.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } catch {
            return (false, "Fehler beim Testen: \(error.localizedDescription)")
        }
    }

    public func cancel(itemId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if let proc = activeProcesses[itemId] {
            proc.terminate()
            activeProcesses.removeValue(forKey: itemId)
        }
    }

    private func cleanupProcess(_ itemId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        activeProcesses.removeValue(forKey: itemId)
    }

    private func appendEngineFlags(arguments: inout [String], settings: AppSettings, allowCookies: Bool) {
        arguments.append(contentsOf: ["--remote-components", "ejs:github"])
        if let node = SystemService.shared.findNodeOrDeno() {
            arguments.append(contentsOf: ["--js-runtimes", "node:\(node)"])
        }

        if allowCookies && settings.useCookies {
            if settings.selectedBrowser == .customFile && !settings.customCookieFilePath.isEmpty {
                let expanded = NSString(string: settings.customCookieFilePath).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expanded) {
                    arguments.append(contentsOf: ["--cookies", expanded])
                }
            } else if settings.selectedBrowser != .customFile {
                arguments.append(contentsOf: ["--cookies-from-browser", settings.selectedBrowser.rawValue])
            }
        }
    }

    private func isCookiePermissionError(_ error: String) -> Bool {
        return error.contains("Operation not permitted") ||
               error.contains("could not find") && error.contains("cookies database") ||
               error.contains("Permission denied") ||
               error.contains("Cookies.binarycookies")
    }

    private func isAgeOrSignInRequired(_ error: String) -> Bool {
        return error.contains("Sign in") ||
               error.contains("age") ||
               error.contains("private") ||
               error.contains("members-only")
    }

    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/Library/Frameworks/Python.framework/Versions/3.11/bin"
        if let currentPath = env["PATH"] {
            env["PATH"] = "\(extraPaths):\(currentPath)"
        } else {
            env["PATH"] = extraPaths
        }
        return env
    }

    public static func formatDuration(seconds: Int) -> String {
        guard seconds > 0 else { return "" }
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}
