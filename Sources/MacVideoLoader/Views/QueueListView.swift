import SwiftUI

public struct QueueListView: View {
    @ObservedObject var downloadManager: DownloadManager
    @State private var isFailedSectionExpanded: Bool = true

    public init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
    }

    private var activeOrCompletedItems: [DownloadItem] {
        downloadManager.queue.filter { !$0.status.isFailed }
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
                        // 1. Regular queue items (active, waiting, completed, paused, skipped)
                        ForEach(activeOrCompletedItems) { item in
                            QueueRowView(item: item, downloadManager: downloadManager)
                        }

                        // 2. Dedicated Error / Failed category grouped at the end of the list
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
            .padding(.top, activeOrCompletedItems.isEmpty ? 0 : 4)

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
                            .font(.system(size: 12))
                        Text("Gespeicherte Download-Liste öffnen...")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
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
    }
}
