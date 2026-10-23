import Foundation

public final class GeminiService: @unchecked Sendable {
    public static let shared = GeminiService()

    private init() {}

    // MARK: - API Key Connection Test

    public func testApiKey(apiKey: String, model: String = "gemini-2.5-flash") async -> (success: Bool, message: String) {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (false, "Bitte gib einen gültigen Google Gemini API-Key ein.")
        }

        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(cleanKey)") else {
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
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorObj = json["error"] as? [String: Any],
                   let errMsg = errorObj["message"] as? String {
                    return (false, "Gemini API Fehler (\(httpResponse.statusCode)): \(errMsg)")
                }
                return (false, "Gemini API antwortete mit Statuscode \(httpResponse.statusCode).")
            }
        } catch {
            return (false, "Netzwerkfehler: \(error.localizedDescription)")
        }
    }

    // MARK: - Live Model List Discovery

    public func fetchModelsFromApi(apiKey: String) async -> [String] {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(cleanKey)") else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsArray = json["models"] as? [[String: Any]] else {
                return []
            }

            var modelIds: [String] = []
            for item in modelsArray {
                if let name = item["name"] as? String,
                   let methods = item["supportedGenerationMethods"] as? [String],
                   methods.contains("generateContent") {
                    let cleanName = name.replacingOccurrences(of: "models/", with: "")
                    if cleanName.contains("gemini") {
                        modelIds.append(cleanName)
                    }
                }
            }
            return modelIds
        } catch {
            return []
        }
    }

    // MARK: - Plex-optimierte KI-Umbenennung

    public func analyzeForPlex(
        items: [FileBotRenameItem],
        apiKey: String,
        model: String = "gemini-2.5-flash",
        seasonPrefix: String = "Season",
        includeYear: Bool = true,
        userPromptHint: String? = nil
    ) async throws -> [PlexNamingProposal] {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "GeminiService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kein Gemini API-Key hinterlegt. Bitte in den Einstellungen eintragen."])
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(cleanKey)") else {
            throw NSError(domain: "GeminiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ungültige Modell-URL."])
        }

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
        - Antworte ausschließlich mit einem JSON-Array von Objekten.
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
            throw NSError(domain: "GeminiService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Keine gültige HTTP-Antwort erhalten."])
        }

        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API Fehler: \(msg)"])
            }
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API antwortete mit Fehlercode \(httpResponse.statusCode)."])
        }

        // Parse Candidates
        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = rootJson["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String,
              let textData = text.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Antwort von Gemini konnte nicht extrahiert werden."])
        }

        let decoder = JSONDecoder()
        if let proposals = try? decoder.decode([PlexNamingProposal].self, from: textData) {
            return proposals
        } else if let single = try? decoder.decode(PlexNamingProposal.self, from: textData) {
            return [single]
        } else {
            throw NSError(domain: "GeminiService", code: 502, userInfo: [NSLocalizedDescriptionKey: "JSON-Struktur der Plex-Vorschläge entspricht nicht dem erwarteten Format."])
        }
    }

    // MARK: - Beliebige Dateien & Markup / Filter KI-Umbenennung

    public func analyzeCustomFiles(
        items: [FileBotRenameItem],
        apiKey: String,
        model: String = "gemini-2.5-flash",
        customInstruction: String
    ) async throws -> [CustomFileNamingProposal] {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "GeminiService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Kein Gemini API-Key hinterlegt. Bitte in den Einstellungen eintragen."])
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(cleanKey)") else {
            throw NSError(domain: "GeminiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ungültige Modell-URL."])
        }

        // Build list of filenames and metadata
        var fileEntries: [[String: Any]] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for (idx, item) in items.enumerated() {
            var entry: [String: Any] = [
                "originalIndex": idx + 1,
                "originalName": item.originalName,
                "pathExtension": item.originalURL.pathExtension.isEmpty ? "" : item.originalURL.pathExtension
            ]
            if let rel = item.relativeSourcePath, !rel.isEmpty {
                entry["relativePath"] = rel
            }
            if let d = item.creationDate ?? item.modificationDate {
                entry["fileDate"] = dateFormatter.string(from: d)
            }
            fileEntries.append(entry)
        }

        let inputJsonData = (try? JSONSerialization.data(withJSONObject: fileEntries, options: .prettyPrinted)) ?? Data()
        let inputJsonString = String(data: inputJsonData, encoding: .utf8) ?? "[]"

        let systemInstruction = """
        Du bist ein intelligenter Dateimanager und Umbenennungs-Assistent für macOS.
        Deine Aufgabe ist es, eine Liste von Dateien anhand der benutzerdefinierten Anweisung präzise und elegant umzubenennen.
        Regeln:
        - Behalte die Dateiendung (Extension) stets bei.
        - Bereinige unschöne Artefakte, Sonderzeichen oder unnötige Nummern/Codes, falls sinnvoll.
        - Falls der Benutzer eine Gruppierung in Unterordner wünscht, gib den Pfad mit Slash ('/') im Feld 'proposedRelativePath' an.
        - Wenn keine Unterordner gewünscht sind, ist 'proposedRelativePath' identisch mit 'proposedName'.
        - Antworte ausschließlich mit einem JSON-Array von Objekten.
        """

        let instructionText = customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Bereinige die Dateinamen sinnvoll, entferne kryptische Zeichen und behalte das Datum bzw. logische Nummern bei."
            : customInstruction

        let userPrompt = """
        Benutzer-Anweisung zur Umbenennung:
        \(instructionText)

        Dateien:
        \(inputJsonString)

        Erzeuge für jede Datei ein JSON-Objekt mit genau folgenden Schlüsseln:
        - "originalName": exakter Name der Originaldatei
        - "proposedName": der empfohlene neue Dateiname inklusive Dateiendung
        - "proposedRelativePath": relativer Pfad (inklusive eventueller Unterordner) oder derselbe wie proposedName
        - "reasoning": kurze Begründung der Benennung
        """

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
            throw NSError(domain: "GeminiService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Keine gültige HTTP-Antwort erhalten."])
        }

        guard httpResponse.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API Fehler: \(msg)"])
            }
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API antwortete mit Fehlercode \(httpResponse.statusCode)."])
        }

        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = rootJson["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String,
              let textData = text.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Antwort von Gemini konnte nicht extrahiert werden."])
        }

        let decoder = JSONDecoder()
        if let proposals = try? decoder.decode([CustomFileNamingProposal].self, from: textData) {
            return proposals
        } else if let single = try? decoder.decode(CustomFileNamingProposal.self, from: textData) {
            return [single]
        } else {
            throw NSError(domain: "GeminiService", code: 502, userInfo: [NSLocalizedDescriptionKey: "JSON-Struktur der Dateivorschläge entspricht nicht dem erwarteten Format."])
        }
    }
}
