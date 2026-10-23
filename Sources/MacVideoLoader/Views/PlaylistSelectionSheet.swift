import SwiftUI
import AppKit

public struct PlaylistSelectionSheet: View {
    public let playlist: PlaylistInfo
    @ObservedObject var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItemIds: Set<String> = []
    @State private var selectedSeasonFilter: String? = nil
    @State private var searchText: String = ""
    @State private var downloadType: DownloadType = .video
    @State private var selectedQuality: VideoQuality = .best
    @State private var selectedAudioFormat: AudioFormat = .mp3

    public init(playlist: PlaylistInfo, downloadManager: DownloadManager) {
        self.playlist = playlist
        self.downloadManager = downloadManager
        // Select all items initially
        _selectedItemIds = State(initialValue: Set(playlist.items.map { $0.id }))
    }

    private var filteredItems: [PlaylistItem] {
        var list = playlist.items

        if let season = selectedSeasonFilter {
            list = list.filter { $0.seasonTitle == season }
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            list = list.filter { item in
                item.title.lowercased().contains(query) ||
                (item.uploader?.lowercased().contains(query) ?? false) ||
                (item.seasonTitle?.lowercased().contains(query) ?? false)
            }
        }

        return list
    }

    private var allFilteredSelected: Bool {
        let filteredIds = Set(filteredItems.map { $0.id })
        return !filteredIds.isEmpty && filteredIds.isSubset(of: selectedItemIds)
    }

    private var extractorBadge: (title: String, icon: String, color: Color) {
        let ext = playlist.extractor.lowercased()
        let isStaffel = playlist.isSeasonOrSeries
        if ext.contains("ard") {
            return (isStaffel ? "ARD Mediathek • Staffel" : "ARD Mediathek", "tv.fill", Color.blue)
        } else if ext.contains("zdf") {
            return (isStaffel ? "ZDF Mediathek • Staffel" : "ZDF Mediathek", "play.tv.fill", Color.orange)
        } else if ext.contains("arte") {
            return (isStaffel ? "Arte • Serie / Staffel" : "Arte", "film.fill", Color.red)
        } else if ext.contains("youtube") {
            return ("YouTube Playlist", "play.rectangle.fill", Color.red)
        } else if ext.contains("vimeo") {
            return ("Vimeo", "video.fill", Color.cyan)
        } else {
            return (isStaffel ? "Mediathek Staffel" : "Webseite", "globe", Color.purple)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Auto-Discovery Banner (if triggered from single episode)
            if playlist.initialSelectedUrl != nil {
                autoDiscoveryBanner
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Season Filter Bar (if multiple seasons detected)
            if playlist.detectedSeasons.count > 1 {
                seasonFilterBar
                Divider()
                    .background(Color.white.opacity(0.08))
            }

            // Toolbar: Search, Select All / None, Format Chooser
            toolbarView

            Divider()
                .background(Color.white.opacity(0.08))

            // Items List
            itemsListView

            Divider()
                .background(Color.white.opacity(0.1))

            // Bottom Actions Bar
            bottomActionBar
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 540, idealHeight: 600)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        .preferredColorScheme(.dark)
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [extractorBadge.color.opacity(0.9), extractorBadge.color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: extractorBadge.color.opacity(0.3), radius: 6, x: 0, y: 2)

                Image(systemName: playlist.isSeasonOrSeries ? "tv.inset.filled" : "square.stack.3d.down.right.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(playlist.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: extractorBadge.icon)
                            .font(.system(size: 10))
                        Text(extractorBadge.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(extractorBadge.color.opacity(0.2))
                    .foregroundColor(extractorBadge.color)
                    .cornerRadius(5)
                }

                Text("\(playlist.items.count) \(playlist.isSeasonOrSeries ? "Episoden" : "Videos") erkannt • Wähle die gewünschten Titel für den Download")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // Dedicated Destination Folder Preview
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow.opacity(0.85))
                    Text("Zielordner:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    let folderLabel: String = {
                        if playlist.isSeasonOrSeries {
                            let series = playlist.effectiveSeriesTitle
                            if playlist.detectedSeasons.count > 1 {
                                return "\(series) / [Staffel 1, Staffel 2...]"
                            } else if let s = playlist.detectedSeasons.first {
                                return "\(series) / \(s)"
                            }
                            return series
                        } else {
                            return playlist.title
                        }
                    }()

                    Text(folderLabel)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(3)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: {
                downloadManager.detectedPlaylist = nil
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Abbrechen")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(red: 0.13, green: 0.13, blue: 0.16))
    }

    // MARK: - Auto-Discovery Banner
    private var autoDiscoveryBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.tv.fill")
                .font(.system(size: 15))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text("Staffel automatisch erkannt!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text("Du hast die URL einer Einzelfolge eingefügt – Mac Video Loader hat automatisch die gesamte Staffel geladen.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Nur Einzelfolge") {
                selectOnlyInitialEpisode()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Ganze Staffel") {
                selectAllEpisodes()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - Season Filter Bar
    private var seasonFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                seasonFilterChip(
                    title: "Alle Staffeln (\(playlist.items.count))",
                    isSelected: selectedSeasonFilter == nil
                ) {
                    selectedSeasonFilter = nil
                }

                ForEach(playlist.detectedSeasons, id: \.self) { season in
                    let count = playlist.items.filter { $0.seasonTitle == season }.count
                    seasonFilterChip(
                        title: "\(season) (\(count))",
                        isSelected: selectedSeasonFilter == season
                    ) {
                        selectedSeasonFilter = season
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.13))
    }

    private func seasonFilterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.blue : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? .white : .secondary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toolbar View
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                TextField("In Episoden / Titeln suchen...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .cornerRadius(6)
            .frame(maxWidth: 220)

            // Select All / Deselect All
            Button(action: toggleSelectAll) {
                HStack(spacing: 4) {
                    Image(systemName: allFilteredSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 12))
                        .foregroundColor(allFilteredSelected ? .red : .secondary)
                    Text(allFilteredSelected ? "Keine auswählen" : "Alle auswählen")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Quick Staffel button if filtering by a single season
            if let season = selectedSeasonFilter {
                Button(action: { selectSeasonOnly(season) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 11))
                        Text("Nur \(season)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.18))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Download Type & Quality Picker
            HStack(spacing: 10) {
                Picker("", selection: $downloadType) {
                    ForEach(DownloadType.allCases) { type in
                        Label(type.title, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)

                if downloadType == .video {
                    Picker("Qualität:", selection: $selectedQuality) {
                        ForEach(VideoQuality.allCases) { q in
                            Text(q.displayName).tag(q)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 160)
                } else {
                    Picker("Format:", selection: $selectedAudioFormat) {
                        ForEach(AudioFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 140)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
    }

    // MARK: - Items List View
    private var itemsListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    let isSelected = selectedItemIds.contains(item.id)
                    let isInitial = playlist.initialSelectedUrl != nil && (item.url == playlist.initialSelectedUrl || item.id == playlist.initialSelectedUrl)

                    HStack(spacing: 12) {
                        // Checkbox
                        Button(action: { toggleSelection(for: item.id) }) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? .red : .gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        // Index number
                        Text("#\(index + 1)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 32, alignment: .leading)

                        // Thumbnail / Icon
                        if let thumbURL = item.thumbnailURL {
                            AsyncImage(url: thumbURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure, .empty:
                                    thumbnailPlaceholder
                                @unknown default:
                                    thumbnailPlaceholder
                                }
                            }
                            .frame(width: 60, height: 36)
                            .cornerRadius(4)
                            .clipped()
                        } else {
                            thumbnailPlaceholder
                        }

                        // Title, Uploader & Season/Episode Badge
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                // Season/Episode Pill Badge
                                if let s = item.seasonNumber, let e = item.episodeNumber {
                                    Text(String(format: "S%02d · E%02d", s, e))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.blue.opacity(0.25))
                                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                        .cornerRadius(4)
                                } else if let s = item.seasonNumber {
                                    Text("Staffel \(s)")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.purple.opacity(0.25))
                                        .foregroundColor(Color(red: 0.8, green: 0.5, blue: 1.0))
                                        .cornerRadius(4)
                                } else if let e = item.episodeNumber {
                                    Text("Folge \(e)")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.teal.opacity(0.25))
                                        .foregroundColor(Color.teal)
                                        .cornerRadius(4)
                                }

                                if isInitial {
                                    Text("Eingefügte Folge")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.orange.opacity(0.25))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                }

                                Text(item.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .lineLimit(1)
                            }

                            if let uploader = item.uploader, !uploader.isEmpty {
                                Text(uploader)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // Duration Badge
                        if let dur = item.duration, !dur.isEmpty {
                            Text(dur)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.secondary)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.white.opacity(0.04) : Color.clear)
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSelection(for: item.id)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.05))
            Image(systemName: playlist.isSeasonOrSeries ? "tv" : "video.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(width: 60, height: 36)
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack {
            // Live Counter
            HStack(spacing: 6) {
                let unitName = playlist.isSeasonOrSeries ? "Episoden" : "Videos"
                Text("\(selectedItemIds.count) von \(playlist.items.count) \(unitName) ausgewählt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)

                if selectedItemIds.count < playlist.items.count {
                    Text("(\(playlist.items.count - selectedItemIds.count) ausgeschlossen)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Abbrechen") {
                downloadManager.detectedPlaylist = nil
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button(action: addSelectedToQueue) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    let unit = playlist.isSeasonOrSeries ? "Episoden" : "Videos"
                    Text("\(selectedItemIds.count) \(unit) in eigene Ordner laden")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.15, blue: 0.2), Color(red: 0.85, green: 0.05, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: Color.red.opacity(0.35), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(selectedItemIds.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.13, green: 0.13, blue: 0.16))
    }

    // MARK: - Helper Actions
    private func toggleSelection(for id: String) {
        if selectedItemIds.contains(id) {
            selectedItemIds.remove(id)
        } else {
            selectedItemIds.insert(id)
        }
    }

    private func toggleSelectAll() {
        let filteredIds = Set(filteredItems.map { $0.id })
        if allFilteredSelected {
            selectedItemIds.subtract(filteredIds)
        } else {
            selectedItemIds.formUnion(filteredIds)
        }
    }

    private func selectAllEpisodes() {
        selectedItemIds = Set(playlist.items.map { $0.id })
    }

    private func selectOnlyInitialEpisode() {
        guard let initURL = playlist.initialSelectedUrl else { return }
        if let match = playlist.items.first(where: { $0.url == initURL || $0.id == initURL }) {
            selectedItemIds = [match.id]
        } else if let first = playlist.items.first {
            selectedItemIds = [first.id]
        }
    }

    private func selectSeasonOnly(_ season: String) {
        let seasonIds = Set(playlist.items.filter { $0.seasonTitle == season }.map { $0.id })
        selectedItemIds = seasonIds
    }

    private func addSelectedToQueue() {
        let selectedList = playlist.items.filter { selectedItemIds.contains($0.id) }
        guard !selectedList.isEmpty else { return }

        downloadManager.addPlaylistItems(
            selectedList,
            playlist: playlist,
            downloadType: downloadType,
            videoQuality: selectedQuality,
            audioFormat: selectedAudioFormat
        )

        downloadManager.detectedPlaylist = nil
        dismiss()
    }
}
