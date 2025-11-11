import Foundation

struct Torrent: Identifiable, Codable {
    let hash: String
    let name: String
    let size: Int64
    let progress: Double
    let dlspeed: Int64
    let upspeed: Int64
    let state: String
    
    var id: String { hash }
}

struct TorrentFile: Identifiable, Codable {
    let index: Int
    let name: String
    let size: Int64
    let progress: Double
    let priority: Int
    let availability: Double
    
    var id: Int { index }
}

struct SearchPlugin: Identifiable, Codable {
    let name: String
    let version: String
    let url: String
    let enabled: Bool
    let fullName: String
    let supportedCategories: [String]
    
    var id: String { name }
}

struct SearchResult: Identifiable, Codable {
    let fileName: String
    let fileUrl: String
    let fileSize: Int64
    let nbSeeders: Int
    let nbLeechers: Int
    let siteUrl: String
    let descrLink: String
    
    var id: String { fileUrl }
}

class QBittorrentAPI: ObservableObject {
    @Published var torrents: [Torrent] = []
    @Published var isConnected = false
    @Published var errorMessage: String = ""
    
    // Static credentials
    private let defaultServerURL = "http://192.168.0.30:8080"
    private let defaultUsername = "admin"
    private let defaultPassword = "password"
    
    var serverURL: String = ""
    var username: String = ""
    private var password: String = ""
    private var cookie: String?
    
    func configure(url: String, username: String, password: String) {
        self.serverURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        self.username = username
        self.password = password
    }
    
    func autoConnect() async {
        // Use default credentials
        self.serverURL = defaultServerURL
        self.username = defaultUsername
        self.password = defaultPassword
        
        await login()
    }
    
    func login() async {
        guard let url = URL(string: "\(serverURL)/api/v2/auth/login") else {
            await MainActor.run {
                self.errorMessage = "Invalid URL format"
                self.isConnected = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let body = "username=\(username)&password=\(password)"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status code: \(httpResponse.statusCode)")
                let responseString = String(data: data, encoding: .utf8) ?? ""
                print("Response: \(responseString)")
                
                if httpResponse.statusCode == 200 && responseString.contains("Ok") {
                    // Extract cookie
                    if let cookies = httpResponse.allHeaderFields["Set-Cookie"] as? String {
                        self.cookie = cookies.components(separatedBy: ";").first
                    }
                    
                    await MainActor.run {
                        self.isConnected = true
                        self.errorMessage = ""
                    }
                } else {
                    await MainActor.run {
                        self.isConnected = false
                        self.errorMessage = "Login failed: \(responseString)"
                    }
                }
            }
        } catch {
            print("Login error: \(error)")
            await MainActor.run {
                self.isConnected = false
                self.errorMessage = "Connection error: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchTorrents() async {
        guard let url = URL(string: "\(serverURL)/api/v2/torrents/info") else { return }
        
        var request = URLRequest(url: url)
        if let cookie = cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decodedTorrents = try JSONDecoder().decode([Torrent].self, from: data)
            
            await MainActor.run {
                self.torrents = decodedTorrents
            }
        } catch {
            print("Fetch torrents error: \(error)")
        }
    }
    
    func pauseTorrent(hash: String) async {
        await performAction(endpoint: "/api/v2/torrents/pause", body: "hashes=\(hash)")
    }
    
    func resumeTorrent(hash: String) async {
        await performAction(endpoint: "/api/v2/torrents/resume", body: "hashes=\(hash)")
    }
    
    func deleteTorrent(hash: String, deleteFiles: Bool = false) async {
        let deleteFilesParam = deleteFiles ? "true" : "false"
        await performAction(endpoint: "/api/v2/torrents/delete", body: "hashes=\(hash)&deleteFiles=\(deleteFilesParam)")
    }
    
    func pauseAll() async {
        await performAction(endpoint: "/api/v2/torrents/pause", body: "hashes=all")
    }
    
    func resumeAll() async {
        await performAction(endpoint: "/api/v2/torrents/resume", body: "hashes=all")
    }
    
    func addTorrentURL(_ urlString: String) async -> Bool {
        return await addTorrentWithOptions(url: urlString)
    }
    
    func addTorrentWithOptions(
        url: String,
        savePath: String? = nil,
        category: String? = nil,
        sequentialDownload: Bool = false,
        firstLastPiecePriority: Bool = false,
        skipHashCheck: Bool = false,
        paused: Bool = false
    ) async -> Bool {
        guard let apiUrl = URL(string: "\(serverURL)/api/v2/torrents/add") else { return false }
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let cookie = cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        var bodyComponents = ["urls=\(url)"]
        
        if let savePath = savePath, !savePath.isEmpty {
            bodyComponents.append("savepath=\(savePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? savePath)")
        }
        
        if let category = category, !category.isEmpty {
            bodyComponents.append("category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)")
        }
        
        if sequentialDownload {
            bodyComponents.append("sequentialDownload=true")
        }
        
        if firstLastPiecePriority {
            bodyComponents.append("firstLastPiecePrio=true")
        }
        
        if skipHashCheck {
            bodyComponents.append("skip_checking=true")
        }
        
        if paused {
            bodyComponents.append("paused=true")
        }
        
        let body = bodyComponents.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        print("🔧 Adding torrent with options: \(body)")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Add torrent response: \(httpResponse.statusCode)")
                return httpResponse.statusCode == 200
            }
        } catch {
            print("❌ Add torrent error: \(error)")
        }
        return false
    }
    
    private func performAction(endpoint: String, body: String) async {
        guard let url = URL(string: "\(serverURL)\(endpoint)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let cookie = cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchTorrents()
        } catch {
            print("Action error: \(error)")
        }
    }
    
    // MARK: - File Management
    
    func getTorrentFiles(hash: String) async -> [TorrentFile] {
        guard let url = URL(string: "\(serverURL)/api/v2/torrents/files?hash=\(hash)") else { return [] }
        
        var request = URLRequest(url: url)
        if let cookie = cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Parse the response
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var files: [TorrentFile] = []
                for (index, dict) in jsonArray.enumerated() {
                    if let name = dict["name"] as? String,
                       let size = dict["size"] as? Int64,
                       let progress = dict["progress"] as? Double,
                       let priority = dict["priority"] as? Int,
                       let availability = dict["availability"] as? Double {
                        let file = TorrentFile(
                            index: index,
                            name: name,
                            size: size,
                            progress: progress * 100,
                            priority: priority,
                            availability: availability
                        )
                        files.append(file)
                    }
                }
                return files
            }
        } catch {
            print("Get files error: \(error)")
        }
        return []
    }
    
    func setFilePriority(hash: String, fileIds: [Int], priority: Int) async {
        let ids = fileIds.map { String($0) }.joined(separator: "|")
        await performAction(endpoint: "/api/v2/torrents/filePrio", body: "hash=\(hash)&id=\(ids)&priority=\(priority)")
    }
    
    // MARK: - Search
    
    func getSearchPlugins() async -> [SearchPlugin] {
        guard let url = URL(string: "\(serverURL)/api/v2/search/plugins") else { return [] }
        
        var request = URLRequest(url: url)
        if let cookie = cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var plugins: [SearchPlugin] = []
                for dict in jsonArray {
                    if let name = dict["name"] as? String,
                       let version = dict["version"] as? String,
                       let url = dict["url"] as? String,
                       let enabled = dict["enabled"] as? Bool,
                       let fullName = dict["fullName"] as? String {
                        let categories = dict["supportedCategories"] as? [String] ?? []
                        let plugin = SearchPlugin(
                            name: name,
                            version: version,
                            url: url,
                            enabled: enabled,
                            fullName: fullName,
                            supportedCategories: categories
                        )
                        plugins.append(plugin)
                    }
                }
                return plugins
            }
        } catch {
            print("Get plugins error: \(error)")
        }
        return []
    }
    
    func searchTorrents(query: String, category: String = "all") async -> [SearchResult] {
        // Start search
        guard let startUrl = URL(string: "\(serverURL)/api/v2/search/start") else {
            print("❌ Invalid start URL")
            return []
        }
        
        var request = URLRequest(url: startUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let cookie = cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        let body = "pattern=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&plugins=enabled&category=\(category)"
        request.httpBody = body.data(using: .utf8)
        
        print("🔍 Starting search for: \(query)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Search start response: \(httpResponse.statusCode)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("📄 Response: \(responseString)")
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📦 JSON: \(json)")
                
                if let searchId = json["id"] as? Int {
                    print("✅ Search ID: \(searchId)")
                    
                    // Poll for results with status check
                    var attempts = 0
                    let maxAttempts = 15
                    var lastTotal = 0
                    var stableCount = 0
                    
                    while attempts < maxAttempts {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        
                        // Check status
                        guard let statusUrl = URL(string: "\(serverURL)/api/v2/search/status?id=\(searchId)") else { break }
                        
                        var statusRequest = URLRequest(url: statusUrl)
                        if let cookie = cookie {
                            statusRequest.setValue(cookie, forHTTPHeaderField: "Cookie")
                        }
                        
                        let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
                        
                        if let statusJson = try? JSONSerialization.jsonObject(with: statusData) as? [[String: Any]],
                           let status = statusJson.first,
                           let statusStr = status["status"] as? String,
                           let total = status["total"] as? Int {
                            
                            print("📊 Status: \(statusStr), Total: \(total)")
                            
                            // Check if results are stable (not increasing)
                            if total > 0 && total == lastTotal {
                                stableCount += 1
                            } else {
                                stableCount = 0
                            }
                            lastTotal = total
                            
                            // Get results if stopped OR if we have results and they're stable for 2 checks
                            if (statusStr == "Stopped" && total > 0) || (total > 0 && stableCount >= 2) {
                                print("🎯 Fetching \(total) results...")
                                
                                // Get results
                                guard let resultsUrl = URL(string: "\(serverURL)/api/v2/search/results?id=\(searchId)&limit=200") else { break }
                                
                                var resultsRequest = URLRequest(url: resultsUrl)
                                if let cookie = cookie {
                                    resultsRequest.setValue(cookie, forHTTPHeaderField: "Cookie")
                                }
                                
                                let (resultsData, _) = try await URLSession.shared.data(for: resultsRequest)
                                let resultsString = String(data: resultsData, encoding: .utf8) ?? ""
                                print("📋 Results data length: \(resultsString.count) chars")
                                
                                if let resultsJson = try? JSONSerialization.jsonObject(with: resultsData) as? [String: Any],
                                   let results = resultsJson["results"] as? [[String: Any]] {
                                    
                                    print("✅ Found \(results.count) results in response")
                                    
                                    var searchResults: [SearchResult] = []
                                    for dict in results {
                                        if let fileName = dict["fileName"] as? String,
                                           let fileUrl = dict["fileUrl"] as? String {
                                            let fileSize = (dict["fileSize"] as? Int64) ?? (dict["fileSize"] as? Int).map { Int64($0) } ?? 0
                                            let nbSeeders = (dict["nbSeeders"] as? Int) ?? 0
                                            let nbLeechers = (dict["nbLeechers"] as? Int) ?? 0
                                            let siteUrl = (dict["siteUrl"] as? String) ?? ""
                                            let descrLink = (dict["descrLink"] as? String) ?? ""
                                            
                                            let result = SearchResult(
                                                fileName: fileName,
                                                fileUrl: fileUrl,
                                                fileSize: fileSize,
                                                nbSeeders: nbSeeders,
                                                nbLeechers: nbLeechers,
                                                siteUrl: siteUrl,
                                                descrLink: descrLink
                                            )
                                            searchResults.append(result)
                                        }
                                    }
                                    
                                    print("✅ Parsed \(searchResults.count) results")
                                    
                                    // Stop search
                                    await stopSearch(id: searchId)
                                    
                                    return searchResults
                                } else {
                                    print("❌ Failed to parse results JSON")
                                }
                                break
                            } else if statusStr == "Stopped" && total == 0 {
                                print("⚠️ Search stopped with no results")
                                break
                            }
                        }
                        
                        attempts += 1
                    }
                    
                    print("⏱️ Search timed out or completed")
                    // Stop search if still running
                    await stopSearch(id: searchId)
                }
            }
        } catch {
            print("❌ Search error: \(error)")
        }
        return []
    }
    
    private func stopSearch(id: Int) async {
        guard let url = URL(string: "\(serverURL)/api/v2/search/stop") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let cookie = cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        request.httpBody = "id=\(id)".data(using: .utf8)
        
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            print("Stop search error: \(error)")
        }
    }
}
