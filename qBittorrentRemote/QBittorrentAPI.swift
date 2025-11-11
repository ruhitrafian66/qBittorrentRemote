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
        guard let url = URL(string: "\(serverURL)/api/v2/torrents/add") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let cookie = cookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        let body = "urls=\(urlString)"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("Add torrent error: \(error)")
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
}
