import Foundation
import AppKit

@MainActor
public class DownloadManager: ObservableObject {
    public static let shared = DownloadManager()

    @Published public var queue: [DownloadItem] = []
    @Published public var isPaused: Bool = false
    @Published public var activeCount: Int = 0
    @Published public var overallProgress: Double = 0.0
    @Published public var detectedPlaylist: PlaylistInfo? = nil
    @Published public var customDestinationFolder: URL? = nil
    @Published public var pendingPlaylistCustomFolder: URL? = nil
    @Published public var isAnalyzingURL: Bool = false
    @Published public var analysisError: String? = nil
    @Published public var analysisProgress: Double = 0.0
    @Published public var analysisStatusText: String = ""
    @Published public var analysisItemsFound: Int = 0
    @Published public var analysisTotalItems: Int? = nil

    // Multi-selection state
    @Published public var selectedItemIds: Set<UUID> = []

    private let settings = AppSettings.shared
    private let service = YTDlpService.shared
    private let persistence = QueuePersistenceService.shared
    private var currentAnalysisTask: Task<Void, Never>?
    private var postProcessingWatchdogs: [UUID: Task<Void, Never>] = [:]

    private init() {
        // 1. Restore queue from persistent storage across app restarts
        let restored = persistence.loadQueue()
        self.queue = restored

        // 2. Setup network monitoring for automatic resumption after systemic drops
        NetworkMonitorService.shared.onNetworkRestored = { [weak self] in
            Task { @MainActor in
                self?.resumeSystemInterruptedDownloads()
            }
        }
        NetworkMonitorService.shared.startMonitoring()

        updateOverallProgress()
    }

    public func persistQueue() {
        persistence.saveQueue(queue)
    }

    public func resumeSystemInterruptedDownloads() {
        var needsProcess = false
        for item in queue {
            if case .failed = item.status, item.retryCount < item.maxRetries {
                item.status = .queued
                needsProcess = true
            }
        }
        if needsProcess {
            processQueue()
        }
    }

    public func cancelAnalysis() {
        currentAnalysisTask?.cancel()
        currentAnalysisTask = nil
        service.cancelInspection()
        isAnalyzingURL = false
        analysisProgress = 0.0
        analysisStatusText = ""
        analysisItemsFound = 0
        analysisTotalItems = nil
        pendingPlaylistCustomFolder = nil
    }

    public func analyzeOrAddURL(
        _ text: String,
        downloadType: DownloadType,
        videoQuality: VideoQuality,
        audioFormat: AudioFormat,
        customDestinationFolder: URL? = nil
    ) {
        let lines = text.components(separatedBy: CharacterSet.newlines)
        var urls: [String] = []

        for line in lines {
            let splitItems = line.components(separatedBy: CharacterSet.whitespaces)
            for item in splitItems {
                let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidURL(trimmed) {
                    urls.append(trimmed)
                }
            }
        }

        guard !urls.isEmpty else { return }

        let effectiveFolder = customDestinationFolder ?? self.customDestinationFolder

        // If multiple URLs were entered at once, enqueue directly
        if urls.count > 1 {
            addURLs(text, downloadType: downloadType, videoQuality: videoQuality, audioFormat: audioFormat, customDestinationFolder: effectiveFolder)
            return
        }

        let singleURL = urls[0]
        cancelAnalysis()

        isAnalyzingURL = true
        analysisError = nil
        analysisProgress = 0.05
        analysisStatusText = "Verbinde mit Webseite & rufe Inhaltsstruktur ab..."
        analysisItemsFound = 0
        analysisTotalItems = nil
        pendingPlaylistCustomFolder = effectiveFolder

        currentAnalysisTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let inspection = try await service.inspectURL(
                    url: singleURL,
                    settings: settings,
                    onProgress: { [weak self] progress, statusText, itemsFound, totalCount in
                        Task { @MainActor in
                            guard let self = self, self.isAnalyzingURL else { return }
                            self.analysisProgress = progress
                            self.analysisStatusText = statusText
                            self.analysisItemsFound = itemsFound
                            self.analysisTotalItems = totalCount
                        }
                    }
                )

                guard self.isAnalyzingURL else { return }

                switch inspection {
                case .playlist(let playlist):
                    self.isAnalyzingURL = false
                    self.analysisProgress = 1.0
                    self.detectedPlaylist = playlist

                case .singleVideo(let meta):
                    let targetFolder = effectiveFolder ?? self.settings.downloadFolder
                    try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
                    let item = DownloadItem(
                        url: singleURL,
                        downloadType: downloadType,
                        videoQuality: videoQuality,
                        audioFormat: audioFormat,
                        destinationFolder: targetFolder,
                        status: .queued
                    )
                    item.title = meta.title.isEmpty ? singleURL : meta.title
                    item.author = meta.author
                    item.duration = meta.duration
                    item.thumbnailURL = meta.thumbnailURL
                    self.queue.append(item)
                    self.persistQueue()
                    self.isAnalyzingURL = false
                    self.processQueue()
                }
            } catch {
                guard self.isAnalyzingURL else { return }
                if error is CancellationError || Task.isCancelled {
                    self.isAnalyzingURL = false
                    self.analysisProgress = 0.0
                    self.analysisStatusText = ""
                    return
                }
                self.isAnalyzingURL = false
                self.analysisProgress = 0.0
                self.analysisError = "Konnte Inhaltsstruktur nicht abrufen: \(error.localizedDescription)"
                self.analysisStatusText = "Fehler: \(error.localizedDescription)"
            }
        }
    }

    public func addPlaylistItems(
        _ items: [PlaylistItem],
        playlist: PlaylistInfo? = nil,
        downloadType: DownloadType,
        videoQuality: VideoQuality,
        audioFormat: AudioFormat,
        customBaseFolder: URL? = nil
    ) {
        guard !items.isEmpty else { return }

        let baseFolder = customBaseFolder ?? pendingPlaylistCustomFolder ?? self.customDestinationFolder ?? settings.downloadFolder

        for pItem in items {
            let targetFolder: URL
            if let pl = playlist {
                targetFolder = pl.targetFolder(for: pItem, baseFolder: baseFolder)
            } else {
                targetFolder = baseFolder
            }

            try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)

            let dItem = DownloadItem(
                url: pItem.url,
                downloadType: downloadType,
                videoQuality: videoQuality,
                audioFormat: audioFormat,
                destinationFolder: targetFolder,
                status: .queued,
                seasonNumber: pItem.seasonNumber,
                episodeNumber: pItem.episodeNumber,
                seasonTitle: pItem.seasonTitle,
                seriesTitle: playlist?.effectiveSeriesTitle
            )
            dItem.title = pItem.title
            dItem.author = pItem.uploader ?? ""
            dItem.duration = pItem.duration ?? ""
            dItem.thumbnailURL = pItem.thumbnailURL
            queue.append(dItem)
        }

        persistQueue()
        processQueue()
    }

    public func addURLs(
        _ text: String,
        downloadType: DownloadType,
        videoQuality: VideoQuality,
        audioFormat: AudioFormat,
        customDestinationFolder: URL? = nil
    ) {
        let lines = text.components(separatedBy: CharacterSet.newlines)
        var urls: [String] = []

        for line in lines {
            let splitItems = line.components(separatedBy: CharacterSet.whitespaces)
            for item in splitItems {
                let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidURL(trimmed) {
                    urls.append(trimmed)
                }
            }
        }

        guard !urls.isEmpty else { return }

        let targetFolder = customDestinationFolder ?? self.customDestinationFolder ?? settings.downloadFolder
        try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)

        for url in urls {
            let item = DownloadItem(
                url: url,
                downloadType: downloadType,
                videoQuality: videoQuality,
                audioFormat: audioFormat,
                destinationFolder: targetFolder,
                status: .queued
            )
            queue.append(item)
            fetchMetadata(for: item)
        }

        persistQueue()
        processQueue()
    }

    public func fetchMetadata(for item: DownloadItem) {
        item.status = .fetchingInfo
        Task {
            do {
                let meta = try await service.fetchMetadata(url: item.url, settings: settings)
                item.title = meta.title
                item.author = meta.author
                item.duration = meta.duration
                item.thumbnailURL = meta.thumbnailURL
                item.status = .queued
                self.persistQueue()
                self.processQueue()
            } catch {
                item.status = .queued
                self.persistQueue()
                self.processQueue()
            }
        }
    }

    public func processQueue() {
        guard !isPaused else {
            SleepPreventionService.shared.disableSleepPrevention()
            return
        }

        let running = queue.filter { $0.status.isActive }
        activeCount = running.count

        // Manage macOS sleep prevention
        if activeCount > 0 {
            SleepPreventionService.shared.enableSleepPrevention()
        } else {
            SleepPreventionService.shared.disableSleepPrevention()
        }

        guard activeCount < settings.maxConcurrentDownloads else { return }

        let availableSlots = settings.maxConcurrentDownloads - activeCount
        let pending = queue.filter { $0.status == .queued }

        for item in pending.prefix(availableSlots) {
            startDownload(item)
        }

        updateOverallProgress()
    }

    private func startDownload(_ item: DownloadItem) {
        item.status = .downloading(progress: item.progress, speed: "Verbinde...", eta: "...")
        activeCount = queue.filter { $0.status.isActive }.count
        if activeCount > 0 {
            SleepPreventionService.shared.enableSleepPrevention()
        }

        Task { [weak self, item] in
            guard let self = self else { return }
            let itemId = item.id
            defer {
                self.cancelWatchdog(for: itemId)
            }
            do {
                let fileURL = try await self.service.download(
                    item: item,
                    settings: self.settings,
                    onProgress: { [weak item, weak self] progress, speed, eta in
                        guard let item = item else { return }
                        item.progress = progress
                        item.speed = speed
                        item.eta = eta
                        item.status = .downloading(progress: progress, speed: speed, eta: eta)
                        self?.updateOverallProgress()
                    },
                    onStageChange: { [weak item, weak self] stage in
                        guard let item = item else { return }
                        item.status = .processing(stage: stage)
                        self?.schedulePostProcessingWatchdog(for: item)
                    }
                )

                self.cancelWatchdog(for: itemId)
                item.completedFileURL = fileURL
                item.status = .completed(filePath: fileURL)
                item.progress = 1.0
                item.speed = ""
                item.eta = ""
                item.retryCount = 0
                self.persistQueue()
                self.processQueue()
            } catch {
                self.cancelWatchdog(for: itemId)
                if case .cancelled = item.status {
                    // Deliberately cancelled
                } else if case .paused = item.status {
                    // Deliberately paused
                } else if case .skipped = item.status {
                    // Deliberately skipped
                } else {
                    let errMsg = error.localizedDescription
                    let isSystemic = self.isNetworkOrSystemicError(errMsg)

                    if isSystemic && item.retryCount < item.maxRetries {
                        item.retryCount += 1
                        let delay = min(30, item.retryCount * 5)
                        item.status = .downloading(
                            progress: item.progress,
                            speed: "Wiederhole (\(item.retryCount)/\(item.maxRetries)) in \(delay)s...",
                            eta: "..."
                        )
                        Task { [weak self] in
                            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                            guard item.status.isActive || item.status == .queued else { return }
                            item.status = .queued
                            self?.processQueue()
                        }
                    } else {
                        item.status = .failed(error: errMsg)
                    }
                }
                self.persistQueue()
                self.processQueue()
            }
        }
    }

    private func isNetworkOrSystemicError(_ error: String) -> Bool {
        let lower = error.lowercased()
        return lower.contains("connection") ||
               lower.contains("network") ||
               lower.contains("timeout") ||
               lower.contains("timed out") ||
               lower.contains("reset by peer") ||
               lower.contains("broken pipe") ||
               lower.contains("eof") ||
               lower.contains("temporary failure") ||
               lower.contains("429") ||
               lower.contains("503") ||
               lower.contains("502") ||
               lower.contains("504") ||
               lower.contains("try again") ||
               lower.contains("unable to download") ||
               lower.contains("rate limit")
    }

    // MARK: - Pause & Resume Actions (Requirement 2)

    public func pause(item: DownloadItem) {
        cancelWatchdog(for: item.id)
        if item.status.isActive {
            service.cancel(itemId: item.id)
        }
        item.status = .paused
        item.speed = ""
        item.eta = ""
        persistQueue()
        processQueue()
    }

    public func resume(item: DownloadItem) {
        item.status = .queued
        item.retryCount = 0
        persistQueue()
        processQueue()
    }

    public func pauseAll() {
        isPaused = true
        for item in queue where item.status.isActive || item.status == .queued {
            if item.status.isActive {
                service.cancel(itemId: item.id)
            }
            item.status = .paused
            item.speed = ""
            item.eta = ""
        }
        activeCount = 0
        SleepPreventionService.shared.disableSleepPrevention()
        persistQueue()
        processQueue()
    }

    public func resumeAll() {
        isPaused = false
        for item in queue where item.status.isPaused || item.status == .queued {
            item.status = .queued
            item.retryCount = 0
        }
        persistQueue()
        processQueue()
    }

    // MARK: - Skip Actions (Requirement 3)

    public func skip(item: DownloadItem) {
        if item.status.isActive {
            service.cancel(itemId: item.id)
        }
        item.status = .skipped
        item.speed = ""
        item.eta = ""
        persistQueue()
        processQueue()
    }

    public func skipSeason(for item: DownloadItem) {
        let targetSeason = item.seasonTitle ?? (item.seasonNumber != nil ? "Staffel \(item.seasonNumber!)" : nil)
        let targetSeries = item.seriesTitle

        for qItem in queue {
            let isSameSeason: Bool
            if let ts = targetSeason {
                isSameSeason = (qItem.seasonTitle == ts) || (qItem.seasonNumber == item.seasonNumber)
            } else {
                isSameSeason = false
            }

            let isSameSeries: Bool
            if let tSeries = targetSeries {
                isSameSeries = (qItem.seriesTitle == tSeries)
            } else {
                isSameSeries = true
            }

            if isSameSeason && isSameSeries {
                if qItem.status.isActive {
                    service.cancel(itemId: qItem.id)
                }
                qItem.status = .skipped
                qItem.speed = ""
                qItem.eta = ""
            }
        }
        persistQueue()
        processQueue()
    }

    // MARK: - Multi-selection Actions (Requirement 5)

    public func toggleSelection(id: UUID) {
        if selectedItemIds.contains(id) {
            selectedItemIds.remove(id)
        } else {
            selectedItemIds.insert(id)
        }
    }

    public func selectAll() {
        selectedItemIds = Set(queue.map { $0.id })
    }

    public func deselectAll() {
        selectedItemIds.removeAll()
    }

    public func pauseSelected() {
        for item in queue where selectedItemIds.contains(item.id) {
            if item.status.isActive || item.status == .queued {
                if item.status.isActive {
                    service.cancel(itemId: item.id)
                }
                item.status = .paused
                item.speed = ""
                item.eta = ""
            }
        }
        persistQueue()
        processQueue()
    }

    public func resumeSelected() {
        for item in queue where selectedItemIds.contains(item.id) {
            if item.status.isPaused || item.status == .skipped || item.status.isTerminal {
                item.status = .queued
                item.retryCount = 0
            }
        }
        persistQueue()
        processQueue()
    }

    public func skipSelected() {
        for item in queue where selectedItemIds.contains(item.id) {
            if item.status.isActive || item.status == .queued || item.status.isPaused {
                if item.status.isActive {
                    service.cancel(itemId: item.id)
                }
                item.status = .skipped
                item.speed = ""
                item.eta = ""
            }
        }
        persistQueue()
        processQueue()
    }

    public func removeSelected() {
        for item in queue where selectedItemIds.contains(item.id) {
            if item.status.isActive {
                service.cancel(itemId: item.id)
            }
        }
        queue.removeAll { selectedItemIds.contains($0.id) }
        selectedItemIds.removeAll()
        persistQueue()
        processQueue()
    }

    // MARK: - List Export & Import (Requirement 6)

    public func exportSelectedOrAllList() {
        let targetItems: [DownloadItem]
        if !selectedItemIds.isEmpty {
            targetItems = queue.filter { selectedItemIds.contains($0.id) }
        } else {
            targetItems = queue
        }

        guard !targetItems.isEmpty else { return }

        let panel = NSSavePanel()
        panel.title = "Download-Liste exportieren"
        panel.nameFieldStringValue = "Mac-Video-Loader-Downloads.mvl"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try persistence.exportList(
                    title: "Download-Liste",
                    items: targetItems,
                    to: url
                )
            } catch {
                print("Fehler beim Exportieren: \(error.localizedDescription)")
            }
        }
    }

    public func importListFromPanel() {
        let panel = NSOpenPanel()
        panel.title = "Download-Liste öffnen"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            _ = importList(from: url)
        }
    }

    public func importList(from url: URL) -> Int {
        do {
            let imported = try persistence.importList(from: url)
            guard !imported.isEmpty else { return 0 }

            var addedCount = 0
            for item in imported {
                if !queue.contains(where: { $0.url == item.url && $0.destinationFolder == item.destinationFolder }) {
                    queue.append(item)
                    addedCount += 1
                }
            }
            persistQueue()
            processQueue()
            return addedCount
        } catch {
            print("Fehler beim Importieren: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Queue Utilities

    public func cancel(item: DownloadItem) {
        cancelWatchdog(for: item.id)
        service.cancel(itemId: item.id)
        item.status = .cancelled
        item.speed = ""
        item.eta = ""
        persistQueue()
        processQueue()
    }

    public func retry(item: DownloadItem) {
        cancelWatchdog(for: item.id)
        item.status = .queued
        item.progress = 0.0
        item.speed = ""
        item.eta = ""
        item.retryCount = 0
        persistQueue()
        processQueue()
    }

    public func retryAllFailed() {
        for item in queue where item.status.isFailed {
            cancelWatchdog(for: item.id)
            item.status = .queued
            item.progress = 0.0
            item.speed = ""
            item.eta = ""
            item.retryCount = 0
        }
        persistQueue()
        processQueue()
    }

    public func removeAllFailed() {
        let failedIds = Set(queue.filter { $0.status.isFailed }.map { $0.id })
        selectedItemIds.subtract(failedIds)
        for id in failedIds {
            cancelWatchdog(for: id)
        }
        queue.removeAll { $0.status.isFailed }
        persistQueue()
        updateOverallProgress()
    }

    public func removeItem(item: DownloadItem) {
        cancelWatchdog(for: item.id)
        if item.status.isActive {
            cancel(item: item)
        }
        selectedItemIds.remove(item.id)
        queue.removeAll { $0.id == item.id }
        persistQueue()
        processQueue()
    }

    // MARK: - Post-Processing Watchdog (Stall-Erkennung)

    private func cancelWatchdog(for itemId: UUID) {
        postProcessingWatchdogs[itemId]?.cancel()
        postProcessingWatchdogs.removeValue(forKey: itemId)
    }

    private func schedulePostProcessingWatchdog(for item: DownloadItem) {
        let itemId = item.id
        cancelWatchdog(for: itemId)
        postProcessingWatchdogs[itemId] = Task { [weak self, weak item] in
            // Warte 60 Sekunden in der Post-Processing-Phase (Container-Optimierung / Muxing)
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            guard !Task.isCancelled, let self = self, let item = item else { return }

            if case .processing = item.status {
                print("Post-Processing Watchdog: Container-Optimierung bei '\(item.title)' reagiert nicht. Starte automatischen Restart...")
                self.service.cancel(itemId: itemId)
                item.status = .queued
                self.persistQueue()
                self.processQueue()
            }
        }
    }

    public func clearCompleted() {
        queue.removeAll { $0.status == .cancelled || $0.status == .skipped || isCompletedStatus($0.status) }
        selectedItemIds.removeAll()
        persistQueue()
        updateOverallProgress()
    }

    public func clearAll() {
        for item in queue where item.status.isActive {
            cancel(item: item)
        }
        queue.removeAll()
        selectedItemIds.removeAll()
        persistQueue()
        updateOverallProgress()
    }

    public func revealInFinder(item: DownloadItem) {
        if let fileURL = item.completedFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            NSWorkspace.shared.open(item.destinationFolder)
        }
    }

    private func isCompletedStatus(_ status: DownloadStatus) -> Bool {
        if case .completed = status { return true }
        return false
    }

    private func updateOverallProgress() {
        let activeOrCompleted = queue.filter { $0.status != .queued && $0.status != .cancelled && $0.status != .skipped }
        guard !activeOrCompleted.isEmpty else {
            overallProgress = 0.0
            return
        }
        let total = activeOrCompleted.reduce(0.0) { $0 + $1.progress }
        overallProgress = total / Double(activeOrCompleted.count)
    }

    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "http" || scheme == "https" else { return false }
        guard let host = url.host, host.contains(".") else { return false }
        return true
    }
}
