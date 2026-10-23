import SwiftUI

public struct ModernProgressBar: View {
    public let progress: Double
    public let status: DownloadStatus

    public init(progress: Double, status: DownloadStatus) {
        self.progress = max(0.0, min(1.0, progress))
        self.status = status
    }

    private var barColor: Color {
        switch status {
        case .completed:
            return Color.green
        case .failed:
            return Color.red
        case .processing:
            return Color.purple
        case .paused:
            return Color.yellow
        case .skipped:
            return Color.gray.opacity(0.4)
        case .downloading:
            return Color.red // YouTube brand accent
        default:
            return Color.gray.opacity(0.5)
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 6)

                // Fill Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [barColor.opacity(0.8), barColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: 6)
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 6)
    }
}
