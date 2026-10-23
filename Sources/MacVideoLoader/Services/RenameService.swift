import Foundation
import AppKit

public final class RenameService: @unchecked Sendable {
    public static let shared = RenameService()

    private let lock = NSLock()

    private init() {}

    public func isAvailable() -> Bool {
        return SystemService.shared.findFilebot(customPath: AppSettings.shared.customFilebotPath) != nil
    }

    public func getVersion() -> String? {
        guard let binary = SystemService.shared.findFilebot(customPath: AppSettings.shared.customFilebotPath) else {
            return nil
        }
        return runSync(executable: binary, arguments: ["-version"])?.components(separatedBy: .newlines).first
    }

    // MARK: - Folder Scanning (Recursive)

    public func scanFolderRecursively(folderURL: URL) -> [RenameItem] {
        let fileManager = FileManager.default
        var results: [RenameItem] = []

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let basePath = folderURL.standardizedFileURL.path

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey])
                if resourceValues.isRegularFile == true {
                    if fileURL.lastPathComponent == ".DS_Store" { continue }

                    let filePath = fileURL.standardizedFileURL.path
                    var relPath = filePath
                    if filePath.hasPrefix(basePath) {
                        relPath = String(filePath.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    }

                    let item = RenameItem(
                        downloadItemId: nil,
                        originalURL: fileURL,
                        originalName: fileURL.lastPathComponent,
                        proposedName: fileURL.lastPathComponent,
                        proposedRelativePath: relPath,
                        targetFolder: folderURL,
                        creationDate: resourceValues.creationDate,
                        modificationDate: resourceValues.contentModificationDate,
                        relativeSourcePath: relPath,
                        isSelected: true
                    )
                    results.append(item)
                }
            } catch {
                continue
            }
        }

        return results.sorted { $0.originalURL.path.localizedStandardCompare($1.originalURL.path) == .orderedAscending }
    }

    // MARK: - Matching / Vorschau

    public func matchFiles(
        items: [RenameItem],
        mode: RenameProcessingMode,
        database: RenameDatabase,
        language: RenameLanguage,
        format: String,
        seriesQuery: String?,
        outputFolder: URL,
        customInstruction: String? = nil,
        aiProvider: AIProvider? = nil,
        onProgress: (@Sendable (Double, String) -> Void)? = nil
    ) async throws {
        onProgress?(0.1, "Initialisiere Abgleich...")

        // 0. If AI is selected
        if database == .gemini {
            let provider = aiProvider ?? AppSettings.shared.selectedAIProvider
            let apiKey = AppSettings.shared.getApiKey(for: provider)
            if apiKey.isEmpty {
                throw NSError(domain: "RenameService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kein \(provider.displayName) API-Key hinterlegt. Bitte trage deinen API-Key in den Einstellungen ein."])
            }

            let model = AppSettings.shared.getModel(for: provider)
            onProgress?(0.3, "Sende Anfrage an \(provider.displayName) (\(model))...")

            if mode == .custom {
                let proposals = try await AIService.shared.analyzeCustomFiles(
                    items: items,
                    provider: provider,
                    apiKey: apiKey,
                    model: model,
                    customInstruction: customInstruction ?? ""
                )

                onProgress?(0.8, "Verarbeite KI-Rückmeldungen...")

                for item in items {
                    if let prop = proposals.first(where: { $0.originalName == item.originalName }) {
                        await MainActor.run {
                            let rel = prop.proposedRelativePath ?? prop.proposedName
                            item.proposedRelativePath = rel
                            item.proposedName = prop.proposedName
                            item.isMatched = true
                            var status = "✨ \(provider.shortName) (\(model))"
                            if let reason = prop.reasoning, !reason.isEmpty {
                                status += " • \(reason)"
                            }
                            item.statusMessage = status
                            item.isError = false
                        }
                    }
                }
                onProgress?(1.0, "Abgleich erfolgreich abgeschlossen!")
                return
            } else {
                let seasonFolder = AppSettings.shared.geminiPlexSeasonFolder
                let includeYear = AppSettings.shared.geminiIncludeYear

                let proposals = try await AIService.shared.analyzeForPlex(
                    items: items,
                    provider: provider,
                    apiKey: apiKey,
                    model: model,
                    seasonPrefix: seasonFolder,
                    includeYear: includeYear,
                    userPromptHint: customInstruction
                )

                onProgress?(0.8, "Wende Plex-Vorschläge an...")

                // Map proposals back to items
                for item in items {
                    if let prop = proposals.first(where: { $0.originalName == item.originalName }) {
                        await MainActor.run {
                            let ext = item.originalURL.pathExtension.isEmpty ? "mp4" : item.originalURL.pathExtension
                            let sPad = String(format: "%02d", prop.seasonNumber)
                            let ePad = String(format: "%02d", prop.episodeNumber)

                            // Apply user custom format template if it deviates from default
                            var formatted = format
                            formatted = formatted.replacingOccurrences(of: "{n}", with: prop.seriesName)
                            formatted = formatted.replacingOccurrences(of: "{s00e00}", with: "S\(sPad)E\(ePad)")
                            formatted = formatted.replacingOccurrences(of: "{s}", with: "\(prop.seasonNumber)")
                            formatted = formatted.replacingOccurrences(of: "{s.pad(2)}", with: sPad)
                            formatted = formatted.replacingOccurrences(of: "{e}", with: "\(prop.episodeNumber)")
                            formatted = formatted.replacingOccurrences(of: "{e.pad(2)}", with: ePad)
                            if let y = prop.year {
                                formatted = formatted.replacingOccurrences(of: "{y}", with: "\(y)")
                            } else {
                                formatted = formatted.replacingOccurrences(of: " ({y})", with: "")
                                formatted = formatted.replacingOccurrences(of: "{y}", with: "")
                            }
                            formatted = formatted.replacingOccurrences(of: "{t}", with: prop.episodeTitle)
                            formatted = formatted.replacingOccurrences(of: " ()", with: "")
                            formatted = formatted.trimmingCharacters(in: .whitespaces)

                            let customRelative = "\(formatted).\(ext)"

                            if mode == .season {
                                item.proposedRelativePath = format != mode.defaultFormat ? customRelative : prop.plexSeasonPath
                                item.proposedName = URL(fileURLWithPath: item.proposedRelativePath).lastPathComponent
                            } else {
                                item.proposedName = format != mode.defaultFormat ? URL(fileURLWithPath: customRelative).lastPathComponent : prop.plexSeriesFileName
                                item.proposedRelativePath = item.proposedName
                            }
                            item.seriesName = prop.seriesName
                            item.seasonNumber = prop.seasonNumber
                            item.episodeNumber = prop.episodeNumber
                            item.isMatched = true
                            var status = "✨ \(provider.shortName) (\(model)) • S\(sPad)E\(ePad)"
                            if let reason = prop.reasoning, !reason.isEmpty {
                                status += " • \(reason)"
                            }
                            item.statusMessage = status
                            item.isError = false
                        }
                    }
                }
                onProgress?(1.0, "Abgleich erfolgreich abgeschlossen!")
                return
            }
        }

        // 1. If mode is custom (Dateien & Markup), apply custom token replacement
        if mode == .custom {
            onProgress?(0.5, "Wende Markup-Tokens auf \(items.count) Dateien an...")
            applyCustomMarkup(items: items, format: format, outputFolder: outputFolder)
            onProgress?(1.0, "Markup erfolgreich angewendet!")
            return
        }

        let filebotPath = SystemService.shared.findFilebot(customPath: AppSettings.shared.customFilebotPath)

        // 2. If CLI tool is installed, attempt matching via CLI
        if let binary = filebotPath {
            do {
                onProgress?(0.4, "Führe Abgleich via Rename-CLI (\(database.rawValue)) durch...")
                try await matchWithCLI(
                    binary: binary,
                    items: items,
                    mode: mode,
                    database: database,
                    language: language,
                    format: format,
                    seriesQuery: seriesQuery,
                    outputFolder: outputFolder
                )
                onProgress?(1.0, "Erfolgreich via Rename-CLI abgeglichen!")
                return
            } catch {
                print("Rename CLI Fehler, weiche auf lokale Heuristik aus: \(error.localizedDescription)")
            }
        }

        // 3. Fallback to smart local season/series pattern matching
        onProgress?(0.6, "Analysiere Dateimuster mit lokaler Heuristik...")
        matchLocally(items: items, mode: mode, format: format, seriesQuery: seriesQuery, outputFolder: outputFolder)
        onProgress?(1.0, "Muster-Abgleich abgeschlossen!")
    }

    private func matchWithCLI(
        binary: String,
        items: [RenameItem],
        mode: RenameProcessingMode,
        database: RenameDatabase,
        language: RenameLanguage,
        format: String,
        seriesQuery: String?,
        outputFolder: URL
    ) async throws {
        let existingFiles = items.compactMap { item -> (RenameItem, String)? in
            let path = item.originalURL.path
            return FileManager.default.fileExists(atPath: path) ? (item, path) : nil
        }

        guard !existingFiles.isEmpty else {
            matchLocally(items: items, mode: mode, format: format, seriesQuery: seriesQuery, outputFolder: outputFolder)
            return
        }

        var arguments = ["-rename"]
        for (_, path) in existingFiles {
            arguments.append(path)
        }

        arguments.append(contentsOf: [
            "--db", database.rawValue,
            "--lang", language.rawValue,
            "--output", outputFolder.path,
            "--format", format,
            "--action", "test",
            "-non-strict"
        ])

        if let query = seriesQuery?.trimmingCharacters(in: .whitespaces), !query.isEmpty {
            arguments.append(contentsOf: ["--q", query])
        }

        let output = try await runProcess(executable: binary, arguments: arguments)
        let matches = parseTestOutput(output)

        // Map matches back to items
        for (idx, (item, oldPath)) in existingFiles.enumerated() {
            if let matchedNewPath = matches[oldPath] ?? matches[(oldPath as NSString).resolvingSymlinksInPath] {
                let newURL = URL(fileURLWithPath: matchedNewPath)
                let relative = relativePath(from: outputFolder, to: newURL)
                Task { @MainActor in
                    item.proposedName = newURL.lastPathComponent
                    item.proposedRelativePath = relative
                    item.isMatched = true
                    item.statusMessage = "Erkannt via CLI (\(database.rawValue))"
                    item.isError = false
                }
            } else {
                applyLocalMatch(item: item, index: idx + 1, mode: mode, format: format, seriesQuery: seriesQuery, explicitSeason: nil, outputFolder: outputFolder)
            }
        }
    }

    private func parseTestOutput(_ output: String) -> [String: String] {
        var matches: [String: String] = [:]
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[TEST] from [") && trimmed.contains("] to [") else { continue }

            let afterFrom = trimmed.replacingOccurrences(of: "[TEST] from [", with: "")
            let parts = afterFrom.components(separatedBy: "] to [")
            guard parts.count == 2 else { continue }

            let oldPath = parts[0]
            var newPath = parts[1]
            if newPath.hasSuffix("]") {
                newPath = String(newPath.dropLast())
            }

            matches[oldPath] = newPath
        }

        return matches
    }

    // MARK: - Smart Local Heuristics Fallback

    public func matchLocally(
        items: [RenameItem],
        mode: RenameProcessingMode,
        format: String,
        seriesQuery: String?,
        outputFolder: URL
    ) {
        if mode == .custom {
            applyCustomMarkup(items: items, format: format, outputFolder: outputFolder)
            return
        }

        var explicitSeason: Int? = nil
        if let query = seriesQuery {
            if let match = query.range(of: #"(?:Staffel|Season)\s*(\d{1,2})"#, options: [.regularExpression, .caseInsensitive]) {
                let digits = String(query[match]).components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                if let first = digits.first {
                    explicitSeason = Int(first)
                }
            }
        }

        for (idx, item) in items.enumerated() {
            applyLocalMatch(
                item: item,
                index: idx + 1,
                mode: mode,
                format: format,
                seriesQuery: seriesQuery,
                explicitSeason: explicitSeason,
                outputFolder: outputFolder
            )
        }
    }

    public func applyCustomMarkup(
        items: [RenameItem],
        format: String,
        outputFolder: URL
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd"

        for (idx, item) in items.enumerated() {
            let index = idx + 1
            let originalFile = item.originalURL.deletingPathExtension().lastPathComponent
            let ext = item.originalURL.pathExtension

            let parentFolder = item.originalURL.deletingLastPathComponent().lastPathComponent

            let fileDate = item.creationDate ?? item.modificationDate ?? Date()
            let dateStr = dateFormatter.string(from: fileDate)
            let yearStr = yearFormatter.string(from: fileDate)
            let monthStr = monthFormatter.string(from: fileDate)
            let dayStr = dayFormatter.string(from: fileDate)

            var clean = originalFile
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            clean = clean.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

            var result = format
            result = result.replacingOccurrences(of: "{original}", with: originalFile)
            result = result.replacingOccurrences(of: "{fn}", with: originalFile)
            result = result.replacingOccurrences(of: "{folder}", with: parentFolder)
            result = result.replacingOccurrences(of: "{ext}", with: ext)

            result = result.replacingOccurrences(of: "{index}", with: "\(index)")
            result = result.replacingOccurrences(of: "{index.pad(2)}", with: String(format: "%02d", index))
            result = result.replacingOccurrences(of: "{index.pad(3)}", with: String(format: "%03d", index))
            result = result.replacingOccurrences(of: "{index.pad(4)}", with: String(format: "%04d", index))

            result = result.replacingOccurrences(of: "{date}", with: dateStr)
            result = result.replacingOccurrences(of: "{year}", with: yearStr)
            result = result.replacingOccurrences(of: "{month}", with: monthStr)
            result = result.replacingOccurrences(of: "{day}", with: dayStr)

            result = result.replacingOccurrences(of: "{clean}", with: clean)
            result = result.replacingOccurrences(of: "{clean.lower}", with: clean.lowercased())
            result = result.replacingOccurrences(of: "{clean.upper}", with: clean.uppercased())
            result = result.replacingOccurrences(of: "{lower}", with: originalFile.lowercased())
            result = result.replacingOccurrences(of: "{upper}", with: originalFile.uppercased())

            result = result.trimmingCharacters(in: .whitespacesAndNewlines)

            let finalRelative: String
            if !ext.isEmpty && !result.hasSuffix(".\(ext)") {
                finalRelative = "\(result).\(ext)"
            } else {
                finalRelative = result
            }
            let finalName = URL(fileURLWithPath: finalRelative).lastPathComponent

            Task { @MainActor in
                item.proposedName = finalName
                item.proposedRelativePath = finalRelative
                item.isMatched = true
                item.statusMessage = "Markup angewendet"
                item.isError = false
            }
        }
    }

    private func applyLocalMatch(
        item: RenameItem,
        index: Int,
        mode: RenameProcessingMode,
        format: String,
        seriesQuery: String?,
        explicitSeason: Int?,
        outputFolder: URL
    ) {
        let baseName = item.originalURL.deletingPathExtension().lastPathComponent
        let ext = item.originalURL.pathExtension.isEmpty ? "mp4" : item.originalURL.pathExtension

        let seriesTitle = (seriesQuery?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 }
            ?? item.seriesName
            ?? extractSeriesTitle(from: baseName)
            ?? "Serie"

        let parentFolder = item.originalURL.deletingLastPathComponent().lastPathComponent
        var folderSeason: Int? = nil
        if let match = parentFolder.range(of: #"(?:Staffel|Season)\s*(\d{1,2})"#, options: [.regularExpression, .caseInsensitive]) {
            let digits = String(parentFolder[match]).components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let first = digits.first {
                folderSeason = Int(first)
            }
        }

        let fallbackSeason = item.seasonNumber ?? explicitSeason ?? folderSeason ?? 1
        let (season, episode, epTitle) = extractSeasonEpisode(from: baseName, fallbackSeason: fallbackSeason, fallbackEpisode: item.episodeNumber, sequentialIndex: index)

        let sPad = String(format: "%02d", season)
        let ePad = String(format: "%02d", episode)
        let cleanTitle = epTitle.trimmingCharacters(in: CharacterSet(charactersIn: " -_"))

        var formattedString = format
        formattedString = formattedString.replacingOccurrences(of: "{n}", with: seriesTitle)
        formattedString = formattedString.replacingOccurrences(of: "{s00e00}", with: "S\(sPad)E\(ePad)")
        formattedString = formattedString.replacingOccurrences(of: "{s}", with: "\(season)")
        formattedString = formattedString.replacingOccurrences(of: "{s.pad(2)}", with: sPad)
        formattedString = formattedString.replacingOccurrences(of: "{e}", with: "\(episode)")
        formattedString = formattedString.replacingOccurrences(of: "{e.pad(2)}", with: ePad)
        formattedString = formattedString.replacingOccurrences(of: "{y}", with: "")

        if cleanTitle.isEmpty {
            formattedString = formattedString.replacingOccurrences(of: " - {t}", with: "")
            formattedString = formattedString.replacingOccurrences(of: "{t}", with: "Folge \(episode)")
        } else {
            formattedString = formattedString.replacingOccurrences(of: "{t}", with: cleanTitle)
        }

        formattedString = formattedString.replacingOccurrences(of: " ()", with: "")
        formattedString = formattedString.trimmingCharacters(in: .whitespaces)

        let finalRelative = "\(formattedString).\(ext)"
        let finalFileName = URL(fileURLWithPath: finalRelative).lastPathComponent

        Task { @MainActor in
            item.proposedName = finalFileName
            item.proposedRelativePath = finalRelative
            item.seasonNumber = season
            item.episodeNumber = episode
            item.seriesName = seriesTitle
            item.isMatched = true
            item.statusMessage = "S\(sPad)E\(ePad) • Muster erkannt"
            item.isError = false
        }
    }

    private func extractSeasonEpisode(from name: String, fallbackSeason: Int, fallbackEpisode: Int?, sequentialIndex: Int) -> (season: Int, episode: Int, title: String) {
        var season = fallbackSeason
        var episode = fallbackEpisode ?? sequentialIndex
        var epTitle = ""

        // Pattern 1: S01E02 or s1e2
        if let match = name.range(of: #"[Ss](\d{1,2})[Ee](\d{1,3})"#, options: .regularExpression) {
            let matchedStr = String(name[match])
            let parts = matchedStr.lowercased().components(separatedBy: "e")
            if parts.count == 2 {
                season = Int(parts[0].replacingOccurrences(of: "s", with: "")) ?? season
                episode = Int(parts[1]) ?? episode
            }
            epTitle = String(name[match.upperBound...])
            return (season, episode, cleanEpisodeTitle(epTitle))
        }

        // Pattern 2: 1x02 or 01x02
        if let match = name.range(of: #"(\d{1,2})x(\d{1,3})"#, options: .regularExpression) {
            let matchedStr = String(name[match])
            let parts = matchedStr.lowercased().components(separatedBy: "x")
            if parts.count == 2 {
                season = Int(parts[0]) ?? season
                episode = Int(parts[1]) ?? episode
            }
            epTitle = String(name[match.upperBound...])
            return (season, episode, cleanEpisodeTitle(epTitle))
        }

        // Pattern 3: Staffel 1 Folge 2 / Season 1 Episode 2
        if let match = name.range(of: #"(?:Staffel|Season)\s*(\d{1,2}).*?(?:Folge|Episode|Ep|Part|Teil)\s*(\d{1,3})"#, options: [.regularExpression, .caseInsensitive]) {
            let matchedStr = String(name[match])
            let digits = matchedStr.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if digits.count >= 2 {
                season = Int(digits[0]) ?? season
                episode = Int(digits[1]) ?? episode
            }
            epTitle = String(name[match.upperBound...])
            return (season, episode, cleanEpisodeTitle(epTitle))
        }

        // Pattern 4: Folge 1 / Episode 1 / Teil 1 / Part 1 / Ep. 1
        if let match = name.range(of: #"(?:Folge|Episode|Ep\.?|Teil|Part)\s*(\d{1,3})"#, options: [.regularExpression, .caseInsensitive]) {
            let matchedStr = String(name[match])
            let digits = matchedStr.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let first = digits.first {
                episode = Int(first) ?? episode
            }
            epTitle = String(name[match.upperBound...])
            return (season, episode, cleanEpisodeTitle(epTitle))
        }

        // Pattern 5: Numbers in brackets or parentheses like "(01)" or "[01]" or "#01"
        if let match = name.range(of: #"[\(\[#](\d{1,3})[\)\]]"#, options: .regularExpression) {
            let matchedStr = String(name[match])
            let digits = matchedStr.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let first = digits.first, let num = Int(first), num > 0 {
                episode = num
                return (season, episode, cleanEpisodeTitle(name))
            }
        }

        // Pattern 6: Leading sequence number like "01 - Title" or "01. Title"
        if let match = name.range(of: #"^\s*(\d{1,3})[\s\.\-_]+"#, options: .regularExpression) {
            let matchedStr = String(name[match])
            let digits = matchedStr.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let first = digits.first, let num = Int(first), num > 0 {
                episode = num
                epTitle = String(name[match.upperBound...])
                return (season, episode, cleanEpisodeTitle(epTitle))
            }
        }

        return (season, episode, cleanEpisodeTitle(name))
    }

    private func extractSeriesTitle(from name: String) -> String? {
        let separators = [" - ", " – ", " | "]
        for sep in separators {
            if name.contains(sep) {
                let parts = name.components(separatedBy: sep)
                if parts.count >= 2 {
                    let first = parts[0].trimmingCharacters(in: .whitespaces)
                    if !first.isEmpty { return first }
                }
            }
        }
        return nil
    }

    private func cleanEpisodeTitle(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespaces)
        while str.hasPrefix("-") || str.hasPrefix("–") || str.hasPrefix("_") || str.hasPrefix(".") {
            str = String(str.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return str
    }

    private func relativePath(from baseFolder: URL, to fullURL: URL) -> String {
        let basePath = baseFolder.path
        let fullPath = fullURL.path

        if fullPath.hasPrefix(basePath) {
            let rel = fullPath.replacingOccurrences(of: basePath, with: "")
            return rel.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return fullURL.lastPathComponent
    }

    // MARK: - Umbenennung Ausführen (mit Fortschritts-Callback)

    public func performRename(
        items: [RenameItem],
        onProgress: (@Sendable (Int, Int, Double, String) -> Void)? = nil,
        onItemRenamed: (@Sendable (UUID, URL, String) -> Void)? = nil
    ) async throws -> Int {
        var successCount = 0
        let selectedItems = items.filter(\.isSelected)
        let totalCount = selectedItems.count

        for (idx, item) in selectedItems.enumerated() {
            let original = item.originalURL
            let fraction = Double(idx) / Double(max(1, totalCount))
            onProgress?(idx, totalCount, fraction, item.originalName)

            guard FileManager.default.fileExists(atPath: original.path) else {
                await MainActor.run {
                    item.isError = true
                    item.statusMessage = "Originaldatei nicht gefunden"
                }
                continue
            }

            let destination = item.proposedDestinationURL

            if original.path == destination.path {
                await MainActor.run {
                    item.isRenamed = true
                    item.statusMessage = "Bereits umbenannt"
                }
                successCount += 1
                continue
            }

            let destFolder = destination.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: original, to: destination)

                await MainActor.run {
                    item.isRenamed = true
                    item.statusMessage = "Erfolgreich umbenannt"
                    item.isError = false
                }

                if let downloadId = item.downloadItemId {
                    onItemRenamed?(downloadId, destination, item.proposedName)
                }

                successCount += 1
            } catch {
                await MainActor.run {
                    item.isError = true
                    item.statusMessage = "Fehler: \(error.localizedDescription)"
                }
            }

            let updatedFraction = Double(idx + 1) / Double(max(1, totalCount))
            onProgress?(idx + 1, totalCount, updatedFraction, item.proposedName)
        }

        onProgress?(totalCount, totalCount, 1.0, "Fertig")
        return successCount
    }

    // MARK: - Process Execution Helper

    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let outString = String(data: outData, encoding: .utf8) ?? ""
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errString = String(data: errData, encoding: .utf8) ?? ""

                    let fullOutput = outString + "\n" + errString
                    continuation.resume(returning: fullOutput)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

// Backward compatibility alias
public typealias FileBotService = RenameService
