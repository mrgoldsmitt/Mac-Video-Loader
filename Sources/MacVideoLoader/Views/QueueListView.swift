import SwiftUI
import AppKit

public struct QueueListView: View {
    @ObservedObject var downloadManager: DownloadManager
    @State private var isCompletedSectionExpanded: Bool = true
    @State private var isFailedSectionExpanded: Bool = true

    public init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
    }

    private var pendingOrActiveItems: [DownloadItem] {
        downloadManager.queue.filter { !$0.status.isFailed && !$0.status.isCompleted }
    }

    private var completedItems: [DownloadItem] {
        downloadManager.queue.filter { $0.status.isCompleted }
    }

    private var failedItems: [DownloadItem] {
        downloadManager.queue.filter { $0.status.isFailed }
    }

    public var body: some View {
        Group {
            if downloadManager.queue.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 1. Regular active/pending queue items (queued, downloading, processing, paused, skipped)
                        if !pendingOrActiveItems.isEmpty {
                            ForEach(pendingOrActiveItems) { item in
                                QueueRowView(item: item, downloadManager: downloadManager)
                            }
                        } else if !completedItems.isEmpty || !failedItems.isEmpty {
                            // Friendly notice when queue is clear but completed/failed items exist at the end
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green.opacity(0.8))
                                Text("Alle anstehenden Downloads wurden abgeschlossen.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                        }

                        // 2. Dedicated Completed Downloads category grouped at the end of the list
                        if !completedItems.isEmpty {
                            completedCategorySection
                        }

                        // 3. Dedicated Error / Failed category grouped at the end of the list
                        if !failedItems.isEmpty {
                            failedCategorySection
                        }
                    }
                    .padding(14)
                }
            }
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    // MARK: - Completed Category Section
    private var completedCategorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category Header
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCompletedSectionExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: isCompletedSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 12)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)

                        Text("Abgeschlossene Downloads")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(completedItems.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.25))
                            .foregroundColor(.green)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.4), lineWidth: 1))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Category Quick Actions
                HStack(spacing: 8) {
                    // Rename Studio Button
                    Button(action: {
                        downloadManager.openRenameStudio(items: completedItems)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.system(size: 10, weight: .bold))
                            Text("Im Rename Studio umbenennen...")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Alle abgeschlossenen Dateien im Rename Studio abgleichen und umbenennen")

                    // Open Folder
                    Button(action: {
                        if let first = completedItems.first {
                            downloadManager.revealInFinder(item: first)
                        } else {
                            NSWorkspace.shared.open(AppSettings.shared.downloadFolder)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                            Text("Im Finder öffnen")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    // Clear Completed
                    Button(action: { downloadManager.clearCompleted() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                            Text("Aufräumen")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(.secondary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Fertige Downloads aus der Liste entfernen (Dateien bleiben auf Festplatte)")
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Category Items
            if isCompletedSectionExpanded {
                VStack(spacing: 8) {
                    ForEach(completedItems) { item in
                        QueueRowView(item: item, downloadManager: downloadManager)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Failed / Error Category Section
    private var failedCategorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category Header
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFailedSectionExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: isFailedSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 12)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)

                        Text("Fehlgeschlagene Downloads")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(failedItems.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.25))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.4), lineWidth: 1))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Category Quick Actions
                HStack(spacing: 8) {
                    Button(action: { downloadManager.retryAllFailed() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("Alle wiederholen")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Alle fehlgeschlagenen Downloads erneut starten")

                    Button(action: { downloadManager.removeAllFailed() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Alle entfernen")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.18))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Alle fehlgeschlagenen Einträge aus der Liste löschen")
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Category Items
            if isFailedSectionExpanded {
                VStack(spacing: 8) {
                    ForEach(failedItems) { item in
                        QueueRowView(item: item, downloadManager: downloadManager)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Color.red.opacity(0.85))
            }

            VStack(spacing: 6) {
                Text("Keine Downloads in der Warteschlange")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("Füge oben eine Webseiten- oder Video-URL ein (z. B. ARD, ZDF, Arte, YouTube, Web) oder ziehe Links oder .mvl-Listen direkt hierher.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                Button(action: { downloadManager.importListFromPanel() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Download-Liste (.mvl) öffnen")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
