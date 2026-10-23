import SwiftUI

public struct StatusBadgeView: View {
    public let status: DownloadStatus

    public init(status: DownloadStatus) {
        self.status = status
    }

    private var badgeColor: Color {
        switch status {
        case .queued:
            return Color.gray
        case .fetchingInfo:
            return Color.blue
        case .downloading:
            return Color.orange
        case .processing:
            return Color.purple
        case .paused:
            return Color.yellow
        case .skipped:
            return Color.secondary
        case .completed:
            return Color.green
        case .failed:
            return Color.red
        case .cancelled:
            return Color.secondary
        }
    }

    private var iconName: String {
        switch status {
        case .queued:
            return "clock.arrow.circlepath"
        case .fetchingInfo:
            return "arrow.triangle.2.circlepath"
        case .downloading:
            return "arrow.down.circle.fill"
        case .processing:
            return "gearshape.arrow.triangle.2.circlepath"
        case .paused:
            return "pause.circle.fill"
        case .skipped:
            return "forward.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }

    private var text: String {
        switch status {
        case .queued:
            return "Wartend"
        case .fetchingInfo:
            return "Prüfe..."
        case .downloading:
            return "Lädt..."
        case .processing(let stage):
            return stage
        case .paused:
            return "Pausiert"
        case .skipped:
            return "Übersprungen"
        case .completed:
            return "Fertig"
        case .failed:
            return "Fehler"
        case .cancelled:
            return "Abgebrochen"
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.18))
        .foregroundColor(badgeColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.35), lineWidth: 0.8)
        )
    }
}
