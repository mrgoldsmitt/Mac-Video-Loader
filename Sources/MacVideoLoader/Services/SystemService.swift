import Foundation

public struct ToolStatus {
    public let ytDlpPath: String?
    public let ytDlpVersion: String?
    public let ffmpegPath: String?
    public let ffmpegVersion: String?
    public let nodePath: String?

    public var isReady: Bool {
        return ytDlpPath != nil && ffmpegPath != nil
    }
}

public class SystemService {
    public static let shared = SystemService()

    private init() {}

    public func findYtDlp(customPath: String = "") -> String? {
        if !customPath.isEmpty && FileManager.default.isExecutableFile(atPath: customPath) {
            return customPath
        }

        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            NSHomeDirectory() + "/.local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return which("yt-dlp")
    }

    public func findFfmpeg(customPath: String = "") -> String? {
        if !customPath.isEmpty && FileManager.default.isExecutableFile(atPath: customPath) {
            return customPath
        }

        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return which("ffmpeg")
    }

    public func findNodeOrDeno() -> String? {
        let candidates = [
            "/opt/homebrew/bin/node",
            "/opt/homebrew/bin/deno",
            "/usr/local/bin/node",
            "/usr/local/bin/deno",
            "/usr/bin/node"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        if let node = which("node") { return node }
        if let deno = which("deno") { return deno }
        return nil
    }

    public func checkToolsStatus(customYtDlp: String = "", customFfmpeg: String = "") -> ToolStatus {
        let ytDlp = findYtDlp(customPath: customYtDlp)
        let ffmpeg = findFfmpeg(customPath: customFfmpeg)
        let node = findNodeOrDeno()

        var ytDlpVer: String? = nil
        var ffmpegVer: String? = nil

        if let ytDlp = ytDlp {
            ytDlpVer = runSync(executable: ytDlp, arguments: ["--version"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let ffmpeg = ffmpeg {
            let output = runSync(executable: ffmpeg, arguments: ["-version"]) ?? ""
            if let firstLine = output.components(separatedBy: .newlines).first {
                ffmpegVer = firstLine.replacingOccurrences(of: "ffmpeg version ", with: "").components(separatedBy: " ").first
            }
        }

        return ToolStatus(
            ytDlpPath: ytDlp,
            ytDlpVersion: ytDlpVer,
            ffmpegPath: ffmpeg,
            ffmpegVersion: ffmpegVer,
            nodePath: node
        )
    }

    private func which(_ binary: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [binary]

        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/Library/Frameworks/Python.framework/Versions/3.11/bin"
        if let currentPath = env["PATH"] {
            env["PATH"] = "\(extraPaths):\(currentPath)"
        } else {
            env["PATH"] = extraPaths
        }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    return str
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private func runSync(executable: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/Library/Frameworks/Python.framework/Versions/3.11/bin"
        if let currentPath = env["PATH"] {
            env["PATH"] = "\(extraPaths):\(currentPath)"
        } else {
            env["PATH"] = extraPaths
        }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
