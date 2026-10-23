import SwiftUI

public struct BatchAddSheet: View {
    @ObservedObject var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var batchText: String = ""
    @State private var downloadType: DownloadType = .video
    @State private var selectedQuality: VideoQuality = .best
    @State private var selectedAudioFormat: AudioFormat = .mp3
    @State private var customFolder: URL?

    public init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
        _customFolder = State(initialValue: downloadManager.customDestinationFolder)
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

            // Target Destination Folder Strip
            HStack(spacing: 8) {
                Image(systemName: customFolder != nil ? "folder.fill.badge.gearshape" : "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(customFolder != nil ? Color(red: 0.35, green: 0.75, blue: 1.0) : .yellow.opacity(0.85))

                Text("Zielordner:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                if let custom = customFolder {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)

                        Text(custom.path)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button(action: {
                            customFolder = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Auf Standard-Zielordner zurücksetzen")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.45), lineWidth: 1)
                    )
                } else {
                    HStack(spacing: 4) {
                        Text("Standard:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(AppSettings.shared.downloadFolder.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                }

                Spacer()

                HStack(spacing: 6) {
                    if customFolder != nil {
                        Button("Standard") {
                            customFolder = nil
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                    }

                    Button(action: chooseFolder) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                            Text(customFolder == nil ? "Ordner wählen..." : "Ändern...")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.22))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(customFolder != nil ? Color.blue.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
            )

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
                    downloadManager.customDestinationFolder = customFolder
                    downloadManager.addURLs(
                        batchText,
                        downloadType: downloadType,
                        videoQuality: selectedQuality,
                        audioFormat: selectedAudioFormat,
                        customDestinationFolder: customFolder
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
        .frame(width: 580, height: 420)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Zielordner wählen"
        panel.message = "Wähle einen Zielordner für diese Downloads:"
        if let current = customFolder {
            panel.directoryURL = current
        } else {
            panel.directoryURL = AppSettings.shared.downloadFolder
        }

        if panel.runModal() == .OK, let url = panel.url {
            customFolder = url
        }
    }
}
