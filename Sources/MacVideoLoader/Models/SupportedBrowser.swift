import Foundation

public enum SupportedBrowser: String, CaseIterable, Identifiable, Codable {
    case safari = "safari"
    case chrome = "chrome"
    case brave = "brave"
    case firefox = "firefox"
    case edge = "edge"
    case customFile = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .safari: return "Apple Safari"
        case .chrome: return "Google Chrome"
        case .brave: return "Brave Browser"
        case .firefox: return "Mozilla Firefox"
        case .edge: return "Microsoft Edge"
        case .customFile: return "Eigene cookies.txt Datei"
        }
    }

    public var iconName: String {
        switch self {
        case .safari: return "safari"
        case .chrome: return "globe"
        case .brave: return "shield.lefthalf.filled"
        case .firefox: return "flame"
        case .edge: return "network"
        case .customFile: return "doc.text"
        }
    }
}
