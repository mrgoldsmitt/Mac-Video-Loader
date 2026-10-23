import SwiftUI

public struct BatchAddSheet: View {
    @ObservedObject var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var batchText: String = ""
    @State private var downloadType: DownloadType = .video
    @State private var selectedQuality: VideoQuality = .best
    @State private var selectedAudioFormat: AudioFormat = .mp3

    public init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
    }

    private var recognizedUrlsCount: Int {
        batchText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
            .count
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
                Text("Mehrere URLs hinzufügen (Stapel-Download)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Füge hier mehrere Webseiten- oder Video-Links ein (ein Link pro Zeile, z. B. YouTube, ARD, ZDF, Arte...):")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // TextEditor
            TextEditor(text: $batchText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(minHeight: 140)

            // Options Strip
            HStack(spacing: 16) {
                Picker("", selection: $downloadType) {
                    ForEach(DownloadType.allCases) { type in
                        Label(type.title, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                if downloadType == .video {
                    Picker("Qualität:", selection: $selectedQuality) {
                        ForEach(VideoQuality.allCases) { q in
                            Text(q.displayName).tag(q)
                        }
                    }
                } else {
                    Picker("Format:", selection: $selectedAudioFormat) {
                        ForEach(AudioFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                }

                Spacer()
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Footer / Action Buttons
            HStack {
                Text("\(recognizedUrlsCount) Link(s) erkannt")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Abbrechen") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Zur Warteschlange hinzufügen") {
                    downloadManager.addURLs(
                        batchText,
                        downloadType: downloadType,
                        videoQuality: selectedQuality,
                        audioFormat: selectedAudioFormat
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(recognizedUrlsCount == 0)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 380)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }
}
