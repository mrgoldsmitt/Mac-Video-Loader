import Foundation

public final class AIService: @unchecked Sendable {
    public static let shared = AIService()

    private init() {}

    // MARK: - Connection & API Key Test

    public func testApiKey(
        provider: AIProvider,
        apiKey: String,
        model: String? = nil
    ) async -> (success: Bool, message: String) {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            return (false, "Bitte gib einen gültigen \(provider.displayName) API-Key ein.")
        }

        let chosenModel = model ?? provider.defaultModel

        switch provider {
        case .gemini:
            return await testGeminiApiKey(apiKey: cleanKey, model: chosenModel)
        case .chatgpt:
            return await testOpenAIApiKey(apiKey: cleanKey, model: chosenModel)
        case .claude:
            return await testClaudeApiKey(apiKey: cleanKey, model: chosenModel)
        }
    }

    private func testGeminiApiKey(apiKey: String, model: String) async -> (success: Bool, message: String) {
        let cleanModel = model.replacingOccurrences(of: "models/", with: "")
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent?key=\(apiKey)") else {
            return (false, "Ungültige API-URL für Modell \(model).")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Test. Antworte nur mit 'OK'."]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.0,
                "maxOutputTokens": 10
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Keine HTTP-Antwort erhalten.")
            }

            if httpResponse.statusCode == 200 {
                return (true, "Verbindung zu Google Gemini (\(model)) erfolgreich verifiziert!")
            } else {
                let errMsg = extractErrorMessage(from: data) ?? "Statuscode \(httpResponse.statusCode)"
                return (false, "Gemini API Fehler (\(httpResponse.statusCode)): \(errMsg)")
            }
        } catch {
            return (false, "Netzwerkfehler: \(error.localizedDescription)")
        }
    }

    private func testOpenAIApiKey(apiKey: String, model: String) async -> (success: Bool, message: String) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return (false, "Ungültige OpenAI API-URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Test. Antworte mit 'OK'."]
            ],
            "max_tokens": 10,
            "temperature": 0.0
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Keine HTTP-Antwort erhalten.")
            }

            if httpResponse.statusCode == 200 {
                return (true, "Verbindung zu ChatGPT (\(model)) erfolgreich verifiziert!")
            } else {
                let errMsg = extractErrorMessage(from: data) ?? "Statuscode \(httpResponse.statusCode)"
                return (false, "OpenAI API Fehler (\(httpResponse.statusCode)): \(errMsg)")
            }
        } catch {
            return (false, "Netzwerkfehler: \(error.localizedDescription)")
        }
    }

    private func testClaudeApiKey(apiKey: String, model: String) async -> (success: Bool, message: String) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return (false, "Ungültige Anthropic API-URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "Test. Antworte mit 'OK'."]
            ],
            "temperature": 0.0
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Keine HTTP-Antwort erhalten.")
            }

            if httpResponse.statusCode == 200 {
                return (true, "Verbindung zu Claude (\(model)) erfolgreich verifiziert!")
            } else {
                let errMsg = extractErrorMessage(from: data) ?? "Statuscode \(httpResponse.statusCode)"
                return (false, "Claude API Fehler (\(httpResponse.statusCode)): \(errMsg)")
            }
        } catch {
            return (false, "Netzwerkfehler: \(error.localizedDescription)")
        }
    }

    // MARK: - Dynamic Model Discovery

    public func fetchAvailableModels(provider: AIProvider, apiKey: String) async throws -> [AIModelOption] {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            return AIModelOption.models(for: provider)
        }

        switch provider {
        case .gemini:
            return try await fetchGeminiModels(apiKey: cleanKey)
        case .chatgpt:
            return try await fetchOpenAIModels(apiKey: cleanKey)
        case .claude:
            return try await fetchClaudeModels(apiKey: cleanKey)
        }
    }

    private func fetchGeminiModels(apiKey: String) async throws -> [AIModelOption] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)") else {
            throw NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ungültige Gemini Models-URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Keine HTTP-Antwort von Google Gemini erhalten."])
        }

        guard httpResponse.statusCode == 200 else {
            let errMsg = extractErrorMessage(from: data) ?? "Statuscode \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API Fehler (\(httpResponse.statusCode)): \(errMsg)"])
        }

        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsList = rootJson["models"] as? [[String: Any]] else {
            throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Ungültiges Modell-Antwortformat von Google Gemini."])
        }

        var options: [AIModelOption] = []
        for item in modelsList {
            guard let rawName = item["name"] as? String else { continue }
            let id = rawName.replacingOccurrences(of: "models/", with: "")

            // Only models supporting generateContent
            if let methods = item["supportedGenerationMethods"] as? [String] {
                guard methods.contains("generateContent") else { continue }
            }

            // Exclude embedding, aqa, imagen, veo
            let lower = id.lowercased()
            if lower.contains("embedding") || lower.contains("aqa") || lower.contains("imagen") || lower.contains("veo") {
                continue
            }

            // Exclude older deprecated models like 2.0-flash or 2.5-flash if marked
            if lower == "gemini-2.0-flash" || lower == "gemini-2.5-flash" {
                continue
            }

            let dispName = (item["displayName"] as? String)?.trimmingCharacters(in: .whitespaces) ?? id
            let desc = (item["description"] as? String)?.trimmingCharacters(in: .whitespaces) ?? "Verfügbares Gemini Modell"
            let isRec = id == "gemini-2.5-flash-lite" || id.contains("flash-lite")

            options.append(AIModelOption(
                id: id,
                provider: .gemini,
                displayName: dispName.isEmpty ? id : dispName,
                description: desc,
                isRecommended: isRec
            ))
        }

        if options.isEmpty {
            return AIModelOption.models(for: .gemini)
        }

        // Sort: Recommended first, then version descending
        options.sort { a, b in
            if a.isRecommended != b.isRecommended {
                return a.isRecommended && !b.isRecommended
            }
            return a.id > b.id
        }

        return options
    }

    private func fetchOpenAIModels(apiKey: String) async throws -> [AIModelOption] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ungültige OpenAI Models-URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Keine HTTP-Antwort von OpenAI erhalten."])
        }

        guard httpResponse.statusCode == 200 else {
            let errMsg = extractErrorMessage(from: data) ?? "Statuscode \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Fehler (\(httpResponse.statusCode)): \(errMsg)"])
        }

        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataList = rootJson["data"] as? [[String: Any]] else {
            throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Ungültiges Modell-Antwortformat von OpenAI."])
        }

        var options: [AIModelOption] = []
        for item in dataList {
            guard let id = item["id"] as? String else { continue }
            let lower = id.lowercased()

            // Filter for chat generation models
            let isChatModel = lower.hasPrefix("gpt-4") || lower.hasPrefix("gpt-3.5") || lower.hasPrefix("o1") || lower.hasPrefix("o3") || lower.hasPrefix("chatgpt-")
            guard isChatModel else { continue }

            if lower.contains("realtime") || lower.contains("audio") || lower.contains("transcription") ||
               lower.contains("embedding") || lower.contains("dall-e") || lower.contains("tts") ||
               lower.contains("whisper") || lower.contains("moderation") || lower.contains("instruct") {
                continue
            }

            let isRec = id == "gpt-4o-mini"
            var desc = "OpenAI Chatmodell"
            if id.contains("mini") {
                desc = "Ultraschnell, präzise & kostengünstig"
            } else if id.contains("o1") || id.contains("o3") {
                desc = "Reasoning-Modell für tiefes logisches Durchdenken"
            } else if id.contains("4o") {
                desc = "Omni-Flaggschiffmodell von OpenAI"
            }

            options.append(AIModelOption(
                id: id,
                provider: .chatgpt,
                displayName: id,
                description: desc,
                isRecommended: isRec
            ))
        }

        if options.isEmpty {
            return AIModelOption.models(for: .chatgpt)
        }

        options.sort { a, b in
            if a.isRecommended != b.isRecommended {
                return a.isRecommended && !b.isRecommended
            }
            return a.id < b.id
        }

        return options
    }

    private func fetchClaudeModels(apiKey: String) async throws -> [AIModelOption] {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            throw NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ungültige Anthropic Models-URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return AIModelOption.models(for: .claude)
        }

        guard httpResponse.statusCode == 200 else {
            return AIModelOption.models(for: .claude)
        }

        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataList = rootJson["data"] as? [[String: Any]] else {
            return AIModelOption.models(for: .claude)
        }

        var options: [AIModelOption] = []
        for item in dataList {
            guard let id = item["id"] as? String else { continue }
            let dispName = (item["display_name"] as? String) ?? id
            let isRec = id.contains("haiku")
            let desc = id.contains("sonnet") ? "Hervorragende Präzision & Detailtreue" :
                       id.contains("haiku") ? "Ultraschnell & kostengünstig" :
                       id.contains("opus") ? "Klassisches Spitzenmodell" : "Claude Modell"

            options.append(AIModelOption(
                id: id,
                provider: .claude,
                displayName: dispName,
                description: desc,
                isRecommended: isRec
            ))
        }

        if options.isEmpty {
            return AIModelOption.models(for: .claude)
        }

        options.sort { a, b in
            if a.isRecommended != b.isRecommended {
                return a.isRecommended && !b.isRecommended
            }
            return a.id > b.id
        }

        return options
    }

    // MARK: - Plex-optimierte KI-Umbenennung

    public func analyzeForPlex(
        items: [RenameItem],
        provider: AIProvider = .gemini,
        apiKey: String,
        model: String? = nil,
        seasonPrefix: String = "Season",
        includeYear: Bool = true,
        userPromptHint: String? = nil
    ) async throws -> [PlexNamingProposal] {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "AIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kein \(provider.displayName) API-Key hinterlegt. Bitte in den Einstellungen eintragen."])
        }

        let chosenModel = model ?? provider.defaultModel

        // Build list of filenames and metadata
        var fileEntries: [[String: Any]] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for (idx, item) in items.enumerated() {
            var entry: [String: Any] = [
                "originalIndex": idx + 1,
                "originalName": item.originalName,
                "pathExtension": item.originalURL.pathExtension.isEmpty ? "mp4" : item.originalURL.pathExtension
            ]
            if let s = item.seriesName, !s.isEmpty { entry["hintSeries"] = s }
            if let sn = item.seasonNumber { entry["hintSeason"] = sn }
            if let en = item.episodeNumber { entry["hintEpisode"] = en }
            if let d = item.creationDate ?? item.modificationDate {
                entry["fileDate"] = dateFormatter.string(from: d)
            }
            fileEntries.append(entry)
        }

        let inputJsonData = (try? JSONSerialization.data(withJSONObject: fileEntries, options: .prettyPrinted)) ?? Data()
        let inputJsonString = String(data: inputJsonData, encoding: .utf8) ?? "[]"

        var hintBlock = ""
        if let hint = userPromptHint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            hintBlock = """
            
            BENUTZER-ANWEISUNG / HINWEISE DES BENUTZERS:
            "\(hint)"
            Befolge diese Benutzerhinweise mit allerhöchster Priorität (z. B. Staffelnummern, Titelhinweise oder Nummerierungslogik)!
            """
        }

        let systemInstruction = """
        Du bist ein präziser Experte für Film- und Serien-Metadaten und optimierst Dateinamen exakt nach den offiziellen Plex Media Server Konventionen.
        
        KRITISCHE REGELN FÜR SERIEN-EPISODEN & NUMMERIERUNG:
        1. ECHTE EPISODEN-REIHENFOLGE RECHERCHIEREN:
           - Viele Serienfolgen tragen ihren Episodentitel im Dateinamen (z. B. 'Der Einstieg', 'Das Duell', 'Babylon').
           - WICHTIG: Ein Titel, der alphabetisch mit 'A' anfängt, ist NICHT automatisch Episode 1!
           - Nutze dein Serienwissen (TMDb / TheTVDB), um herauszufinden, zu welcher Staffel und welcher Episodennummer dieser Titel tatsächlich gehört!
        2. NIEMALS ALLE FOLGEN MIT S01E01 BENENNEN:
           - Vergib NIEMALS allen Dateien dieselbe Episodennummer (wie s01e01)! Jede Folge in einer Staffel muss eine eindeutige, aufsteigende Episodennummer haben (z. B. s01e01, s01e02, s01e03...).
           - Falls die Episodentitel in keiner Datenbank auffindbar sind, nutze die Reihenfolge der Dateien ('originalIndex' oder 'fileDate') und nummeriere die Folgen fortlaufend (Episode 1, 2, 3...) durch.
        3. DATEINAMEN-SCHEMA:
           - Schema Serien-Datei: '{ShowName} ({Year}) - s{SS}e{EE} - {EpisodeTitle}.{ext}' (oder ohne Jahr falls unbekannt: '{ShowName} - s{SS}e{EE} - {EpisodeTitle}.{ext}').
           - Schema Staffel-Ordner: '{ShowName} ({Year})/\(seasonPrefix) {SS}/{ShowName} ({Year}) - s{SS}e{EE} - {EpisodeTitle}.{ext}'.
           - {SS} und {EE} müssen immer zweistellig formatiert sein: 's01e01' (NIEMALS 'e01s01').
        4. BEREINIGUNG:
           - Bereinige nervige Mediathek-Artefakte wie 'ARD Mediathek', 'ZDFinfo', '1080p', 'HD', 'x264', Kanalnamen oder Web-Tags vollständig aus dem Titel.
        5. FILME:
           - Falls es sich um einen Film handelt: '{MovieTitle} ({Year}).{ext}' und '{MovieTitle} ({Year})/{MovieTitle} ({Year}).{ext}'.
        - Antworte ausschließlich mit einem JSON-Array von Objekten oder einem Objekt mit Schlüssel 'proposals'.
        """

        let userPrompt = """
        Analysiere die folgenden Dateinamen und erstelle für jede Datei den optimalen Plex-Vorschlag.
        Dateien:
        \(inputJsonString)
        \(hintBlock)

        Erzeuge für jeden Eintrag ein JSON-Objekt mit genau folgenden Schlüsseln:
        - "originalName": exakter Name der Originaldatei
        - "seriesName": bereinigter Name der Serie / des Films
        - "year": Erscheinungsjahr als Zahl (z.B. 2020) oder null
        - "seasonNumber": Staffelnummer als Zahl (z.B. 1)
        - "episodeNumber": Episodennummer als Zahl (z.B. 1, 2, 3...)
        - "episodeTitle": sauberer Episodentitel in deutscher oder Originalsprache
        - "isMovie": boolean
        - "plexSeriesFileName": der vollständige neue Dateiname für Serienverarbeitung
        - "plexSeasonPath": der relative Pfad inklusive Staffelordner für Staffelverarbeitung
        - "reasoning": kurze Begründung der Zuordnung
        """

        let responseText: String
        switch provider {
        case .gemini:
            responseText = try await executeGeminiRequest(
                apiKey: cleanKey,
                model: chosenModel,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt
            )
        case .chatgpt:
            responseText = try await executeOpenAIRequest(
                apiKey: cleanKey,
                model: chosenModel,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt
            )
        case .claude:
            responseText = try await executeClaudeRequest(
                apiKey: cleanKey,
                model: chosenModel,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt
            )
        }

        return try parsePlexProposals(from: responseText)
    }

    // MARK: - Beliebige Dateien & Markup / Filter KI-Umbenennung

    public func analyzeCustomFiles(
        items: [RenameItem],
        provider: AIProvider = .gemini,
        apiKey: String,
        model: String? = nil,
        customInstruction: String
    ) async throws -> [CustomFileNamingProposal] {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "AIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kein \(provider.displayName) API-Key hinterlegt. Bitte in den Einstellungen eintragen."])
        }

        let chosenModel = model ?? provider.defaultModel

        var fileEntries: [[String: Any]] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for (idx, item) in items.enumerated() {
            var entry: [String: Any] = [
                "originalIndex": idx + 1,
                "originalName": item.originalName,
                "pathExtension": item.originalURL.pathExtension.isEmpty ? "" : item.originalURL.pathExtension
            ]
            if let rel = item.relativeSourcePath { entry["relativeSourcePath"] = rel }
            if let d = item.creationDate ?? item.modificationDate {
                entry["fileDate"] = dateFormatter.string(from: d)
            }
            fileEntries.append(entry)
        }

        let inputJsonData = (try? JSONSerialization.data(withJSONObject: fileEntries, options: .prettyPrinted)) ?? Data()
        let inputJsonString = String(data: inputJsonData, encoding: .utf8) ?? "[]"

        let systemInstruction = """
        Du bist ein intelligenter Datei-Organisator und Experte für strukturierte Dateibenennungen auf macOS.
        Deine Aufgabe ist es, beliebige Dateien (Videos, Dokumente, Audio, Bilder oder Rechnungen) intelligent und konsistent umzubennen.
        
        WICHTIGE ANWEISUNGEN:
        1. Befolge die Benutzeranweisungen exakt (z. B. 'Rechnungen nach Datum und Firma sortieren', 'Fotos nummerieren', 'Web-Artefakte entfernen').
        2. Behalte die Dateiendung immer bei.
        3. Falls Ordnerstrukturen gewünscht sind, gib sie in 'proposedRelativePath' mit '/' an (z. B. '2024/2024-05-18 - Rechnung.pdf').
        4. Antworte ausschließlich mit einem JSON-Array von Objekten oder einem Objekt mit Schlüssel 'proposals'.
        """

        let userPrompt = """
        Benutzeranweisung zur Umbenennung:
        "\(customInstruction.isEmpty ? "Benenne die Dateien sauber, einheitlich und lesbar um. Entferne Sonderzeichen und Artefakte." : customInstruction)"

        Dateiliste:
        \(inputJsonString)

        Erzeuge für jede Datei ein JSON-Objekt mit genau folgenden Schlüsseln:
        - "originalName": der unveränderte Name der Originaldatei
        - "proposedName": der empfohlene neue Dateiname (inklusive Endung)
        - "proposedRelativePath": relativer Pfad inklusive Unterordner falls passend, sonst derselbe wie proposedName
        - "reasoning": kurze Begründung des Schemas
        """

        let responseText: String
        switch provider {
        case .gemini:
            responseText = try await executeGeminiRequest(
                apiKey: cleanKey,
                model: chosenModel,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt
            )
        case .chatgpt:
            responseText = try await executeOpenAIRequest(
                apiKey: cleanKey,
                model: chosenModel,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt
            )
        case .claude:
            responseText = try await executeClaudeRequest(
                apiKey: cleanKey,
                model: chosenModel,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt
            )
        }

        return try parseCustomProposals(from: responseText)
    }

    // MARK: - Provider Execution Wrappers

    private func executeGeminiRequest(
        apiKey: String,
        model: String,
        systemInstruction: String,
        userPrompt: String
    ) async throws -> String {
        let cleanModel = model.replacingOccurrences(of: "models/", with: "")
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent?key=\(apiKey)") else {
            throw NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ungültige Gemini Modell-URL."])
        }

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(systemInstruction)\n\n\(userPrompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Keine HTTP-Antwort erhalten."])
        }

        guard httpResponse.statusCode == 200 else {
            let errMsg = extractErrorMessage(from: data) ?? "Statuscode \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google Gemini Fehler (\(httpResponse.statusCode)): \(errMsg)"])
        }

        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = rootJson["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Antwort von Gemini konnte nicht extrahiert werden."])
        }

        return text
    }

    private func executeOpenAIRequest(
        apiKey: String,
        model: String,
        systemInstruction: String,
        userPrompt: String
    ) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ungültige OpenAI URL."])
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemInstruction],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.1,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Keine HTTP-Antwort von OpenAI erhalten."])
        }

        guard httpResponse.statusCode == 200 else {
            let errMsg = extractErrorMessage(from: data) ?? "Statuscode \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI Fehler (\(httpResponse.statusCode)): \(errMsg)"])
        }

        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = rootJson["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Antwort von ChatGPT konnte nicht extrahiert werden."])
        }

        return text
    }

    private func executeClaudeRequest(
        apiKey: String,
        model: String,
        systemInstruction: String,
        userPrompt: String
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ungültige Anthropic URL."])
        }

        let fullSystem = "\(systemInstruction)\nWICHTIG: Antworte AUSSCHLIESSLICH mit reinem JSON ohne Markdown-Codeblöcke und ohne Begleittext."

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": fullSystem,
            "messages": [
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Keine HTTP-Antwort von Claude erhalten."])
        }

        guard httpResponse.statusCode == 200 else {
            let errMsg = extractErrorMessage(from: data) ?? "Statuscode \(httpResponse.statusCode)"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Claude Fehler (\(httpResponse.statusCode)): \(errMsg)"])
        }

        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = rootJson["content"] as? [[String: Any]],
              let firstContent = contents.first,
              let text = firstContent["text"] as? String else {
            throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Antwort von Claude konnte nicht extrahiert werden."])
        }

        return text
    }

    // MARK: - Parsing Helpers

    private func parsePlexProposals(from jsonString: String) throws -> [PlexNamingProposal] {
        let cleaned = cleanMarkdownFences(jsonString)
        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Konnte JSON-Antwort nicht kodieren."])
        }

        let decoder = JSONDecoder()

        // 1. Direct array: [PlexNamingProposal]
        if let array = try? decoder.decode([PlexNamingProposal].self, from: data) {
            return array
        }

        // 2. Object with nested key ("proposals", "items", "files", "results")
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["proposals", "items", "files", "data", "results"] {
                if let nested = dict[key],
                   let nestedData = try? JSONSerialization.data(withJSONObject: nested),
                   let array = try? decoder.decode([PlexNamingProposal].self, from: nestedData) {
                    return array
                }
            }
        }

        // 3. Single proposal: PlexNamingProposal
        if let single = try? decoder.decode(PlexNamingProposal.self, from: data) {
            return [single]
        }

        throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "JSON-Struktur der Plex-Vorschläge entspricht nicht dem erwarteten Format."])
    }

    private func parseCustomProposals(from jsonString: String) throws -> [CustomFileNamingProposal] {
        let cleaned = cleanMarkdownFences(jsonString)
        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Konnte JSON-Antwort nicht kodieren."])
        }

        let decoder = JSONDecoder()

        // 1. Direct array: [CustomFileNamingProposal]
        if let array = try? decoder.decode([CustomFileNamingProposal].self, from: data) {
            return array
        }

        // 2. Object with nested key
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["proposals", "items", "files", "data", "results"] {
                if let nested = dict[key],
                   let nestedData = try? JSONSerialization.data(withJSONObject: nested),
                   let array = try? decoder.decode([CustomFileNamingProposal].self, from: nestedData) {
                    return array
                }
            }
        }

        // 3. Single proposal
        if let single = try? decoder.decode(CustomFileNamingProposal.self, from: data) {
            return [single]
        }

        throw NSError(domain: "AIService", code: 502, userInfo: [NSLocalizedDescriptionKey: "JSON-Struktur der Dateivorschläge entspricht nicht dem erwarteten Format."])
    }

    private func cleanMarkdownFences(_ text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("```json") {
            str = String(str.dropFirst(7))
        } else if str.hasPrefix("```") {
            str = String(str.dropFirst(3))
        }
        if str.hasSuffix("```") {
            str = String(str.dropLast(3))
        }
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // 1. {"error": {"message": "..."}}
        if let errObj = json["error"] as? [String: Any],
           let msg = errObj["message"] as? String {
            return msg
        }

        // 2. {"message": "..."}
        if let msg = json["message"] as? String {
            return msg
        }

        // 3. {"error": "..."}
        if let msg = json["error"] as? String {
            return msg
        }

        return nil
    }
}

// Backward compatibility alias
public typealias GeminiService = AIService
