import SwiftUI
import AppKit

public struct HeaderInputView: View {
    @ObservedObject var downloadManager: DownloadManager
    @Binding var showBatchSheet: Bool

    @State private var urlText: String = ""
    @State private var downloadType: DownloadType = .video
    @State private var selectedQuality: VideoQuality = .best
    @State private var selectedAudioFormat: AudioFormat = .mp3

    public init(downloadManager: DownloadManager, showBatchSheet: Binding<Bool>) {
        self.downloadManager = downloadManager
        self._showBatchSheet = showBatchSheet
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Main Input Bar
            HStack(spacing: 10) {
                // Link Icon
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)

                // TextField
                TextField("Webseiten- oder Video-URL einfügen (YouTube, ARD, ZDF, Arte, Webseiten...)", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white)
                    .disabled(downloadManager.isAnalyzingURL)
                    .onSubmit {
                        submitURL()
                    }

                // Paste from Clipboard Button
                Button(action: pasteFromClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11))
                        Text("Einfügen")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(downloadManager.isAnalyzingURL)
                .help("URL aus der Zwischenablage einfügen")

                if !urlText.isEmpty {
                    Button(action: { urlText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(downloadManager.isAnalyzingURL)
                }

                if downloadManager.isAnalyzingURL {
                    // Status Pill
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .colorInvert()
                        Text("Analysiere (\(Int(downloadManager.analysisProgress * 100))%)...")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                    )

                    // Cancel Button directly in input bar
                    Button(action: {
                        downloadManager.cancelAnalysis()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Abbrechen")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color(red: 0.8, green: 0.1, blue: 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(7)
                        .shadow(color: Color.red.opacity(0.4), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .help("Playlist-Analyse sofort abbrechen (Esc)")
                } else {
                    // Normal Add Button
                    Button(action: submitURL) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Hinzufügen")
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
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.vertical, 6)
            .padding(.trailing, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            // Selector Strip: Video / Audio + Quality / Format Dropdown + Batch Button
            HStack(spacing: 16) {
                // Video vs Audio Picker
                Picker("", selection: $downloadType) {
                    ForEach(DownloadType.allCases) { type in
                        Label(type.title, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                // Quality or Audio Format Menu
                if downloadType == .video {
                    HStack(spacing: 6) {
                        Text("Auflösung:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Picker("", selection: $selectedQuality) {
                            ForEach(VideoQuality.allCases) { q in
                                Text(q.displayName).tag(q)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 260)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("Audioformat:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Picker("", selection: $selectedAudioFormat) {
                            ForEach(AudioFormat.allCases) { fmt in
                                Text(fmt.displayName).tag(fmt)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 220)
                    }
                }

                Spacer()

                // Batch Add Button
                Button(action: { showBatchSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 12))
                        Text("Mehrere URLs...")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Mehrere Links oder Playlists auf einmal importieren")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.08)),
            alignment: .bottom
        )
    }

    private func submitURL() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        downloadManager.analyzeOrAddURL(
            trimmed,
            downloadType: downloadType,
            videoQuality: selectedQuality,
            audioFormat: selectedAudioFormat
        )
        urlText = ""
    }

    private func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            urlText = string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
