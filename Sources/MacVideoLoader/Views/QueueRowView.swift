import SwiftUI

public struct QueueRowView: View {
    @ObservedObject var item: DownloadItem
    @ObservedObject var downloadManager: DownloadManager

    public init(item: DownloadItem, downloadManager: DownloadManager) {
        self.item = item
        self.downloadManager = downloadManager
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Multi-Selection Checkbox (Requirement 5)
            Button(action: { downloadManager.toggleSelection(id: item.id) }) {
                Image(systemName: downloadManager.selectedItemIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(downloadManager.selectedItemIds.contains(item.id) ? .blue : .gray.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help("Diesen Download markieren")

            // Thumbnail Preview
            ZStack(alignment: .bottomTrailing) {
                if let thumb = item.thumbnailURL {
                    AsyncImage(url: thumb) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .empty:
                            thumbnailPlaceholder(isLoading: true)
                        case .failure:
                            thumbnailPlaceholder(isLoading: false)
                        @unknown default:
                            thumbnailPlaceholder(isLoading: false)
                        }
                    }
                    .frame(width: 96, height: 56)
                    .clipped()
                    .cornerRadius(6)
                } else {
                    thumbnailPlaceholder(isLoading: item.status == .fetchingInfo)
                        .frame(width: 96, height: 56)
                        .cornerRadius(6)
                }

                // Duration badge
                if !item.duration.isEmpty {
                    Text(item.duration)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(3)
                        .padding(4)
                }
            }
            .frame(width: 96, height: 56)

            // Info & Progress Section
            VStack(alignment: .leading, spacing: 5) {
                // Title and Format Badge
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Format Badge (e.g. 1080p MP4 or MP3)
                    Text(item.formatBadgeText)
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white.opacity(0.9))
                        .cornerRadius(4)

                    StatusBadgeView(status: item.status)
                }

                // Subtitle: Author or Channel + Folder Badge
                HStack(spacing: 8) {
                    if !item.author.isEmpty {
                        Text(item.author)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if item.destinationFolder.path != AppSettings.shared.downloadFolder.path {
                        let folderName: String = {
                            if item.destinationFolder.path.hasPrefix(AppSettings.shared.downloadFolder.path) {
                                let sub = item.destinationFolder.path.replacingOccurrences(of: AppSettings.shared.downloadFolder.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                return sub.isEmpty ? item.destinationFolder.lastPathComponent : sub
                            } else {
                                return item.destinationFolder.lastPathComponent
                            }
                        }()

                        if !folderName.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.yellow.opacity(0.85))
                                Text(folderName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(3)
                            .help(item.destinationFolder.path)
                        }
                    }
                }

                // Progress Bar & Info
                VStack(spacing: 4) {
                    ModernProgressBar(progress: item.progress, status: item.status)

                    // Progress Details
                    HStack {
                        switch item.status {
                        case .downloading(let pct, let speed, let eta):
                            Text("\(Int(pct * 100))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(speed)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Noch \(eta)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        case .processing(let stage):
                            Text(stage)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.purple)
                        case .paused:
                            Text("Pausiert – Klicke auf Fortsetzen")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        case .skipped:
                            Text("Übersprungen")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        case .completed:
                            Text("Erfolgreich gespeichert")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        case .failed(let err):
                            Text(err)
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                                .lineLimit(1)
                        case .queued:
                            Text("Wartet auf Start...")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        case .fetchingInfo:
                            Text("Lade Video-Metadaten...")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        case .cancelled:
                            Text("Download abgebrochen")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 6) {
                // Pause / Resume button (Requirement 2)
                if item.status.isActive || item.status == .queued {
                    Button(action: { downloadManager.pause(item: item) }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Download pausieren")
                } else if item.status.isPaused {
                    Button(action: { downloadManager.resume(item: item) }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.green.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Download fortsetzen")
                }

                // Skip button (Requirement 3)
                if !item.status.isTerminal {
                    Button(action: { downloadManager.skip(item: item) }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Diesen Download überspringen")
                }

                // Rename Studio button when completed
                if case .completed = item.status {
                    Button(action: { downloadManager.openRenameStudio(items: [item]) }) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 26, height: 26)
                            .background(Color.blue.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Im Rename Studio umbenennen...")

                    Button(action: { downloadManager.revealInFinder(item: item) }) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Im Finder anzeigen")
                }

                // Retry button when failed or cancelled or skipped
                if item.status == .cancelled || item.status == .skipped || isFailedStatus(item.status) {
                    Button(action: { downloadManager.retry(item: item) }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Erneut versuchen")
                }

                // Delete / Remove button
                Button(action: { downloadManager.removeItem(item: item) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Aus Liste entfernen")
            }
        }
        .padding(10)
        .background(downloadManager.selectedItemIds.contains(item.id) ? Color.blue.opacity(0.08) : Color(red: 0.14, green: 0.14, blue: 0.16))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(downloadManager.selectedItemIds.contains(item.id) ? Color.blue.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .contextMenu {
            if item.status.isActive || item.status == .queued {
                Button("Pausieren") {
                    downloadManager.pause(item: item)
                }
            } else if item.status.isPaused {
                Button("Fortsetzen") {
                    downloadManager.resume(item: item)
                }
            }

            if !item.status.isTerminal {
                Button("Diesen Download überspringen") {
                    downloadManager.skip(item: item)
                }

                if let sTitle = item.seasonTitle ?? (item.seasonNumber != nil ? "Staffel \(item.seasonNumber!)" : nil) {
                    Button("Ganze \(sTitle) überspringen") {
                        downloadManager.skipSeason(for: item)
                    }
                }

                if let series = item.seriesTitle {
                    Button("Ganze Serie '\(series)' überspringen") {
                        downloadManager.skipSeries(for: item)
                    }
                }
            }

            if case .completed = item.status {
                Button("Im Rename Studio umbenennen...") {
                    downloadManager.openRenameStudio(items: [item])
                }
            }

            Divider()

            Button("Im Finder anzeigen") {
                downloadManager.revealInFinder(item: item)
            }

            Button("URL kopieren") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url, forType: .string)
            }

            Divider()

            Button("Erneut versuchen") {
                downloadManager.retry(item: item)
            }

            Button("Aus Warteschlange entfernen", role: .destructive) {
                downloadManager.removeItem(item: item)
            }
        }
    }

    private func thumbnailPlaceholder(isLoading: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.4)
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: item.downloadType == .video ? "video.fill" : "waveform")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    private func isFailedStatus(_ status: DownloadStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }
}
