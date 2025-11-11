# Developer Documentation

## Project Overview

qBittorrent Remote is a native iOS app for managing qBittorrent-nox-static servers over HTTP. Built with SwiftUI and targeting iOS 15+.

## Architecture

### Core Components

**ContentView.swift**
- Main entry point with auto-connect logic
- Handles connection state and settings display

**TorrentListView.swift**
- Primary torrent management interface
- Filter tabs, search, swipe actions
- Bulk operations (pause/resume all, remove missing)

**SearchView.swift**
- Torrent discovery using qBittorrent search plugins
- Category filtering, result display
- Direct torrent addition from search

**TorrentFilesView.swift**
- Selective file download management
- Per-file priority control
- Bulk file selection

**QBittorrentAPI.swift**
- All API communication logic
- Cookie-based authentication
- Async/await network calls

## Data Models

```swift
struct Torrent: Identifiable, Codable {
    let hash: String        // Unique identifier
    let name: String        // Display name
    let size: Int64         // Total size in bytes
    let progress: Double    // 0-100
    let dlspeed: Int64      // Download speed (bytes/s)
    let upspeed: Int64      // Upload speed (bytes/s)
    let state: String       // Current state
}

struct TorrentFile: Identifiable, Codable {
    let index: Int          // File index
    let name: String        // File path
    let size: Int64         // File size
    let progress: Double    // Download progress
    let priority: Int       // 0=skip, 1+=download
    let availability: Double
}

struct SearchResult: Identifiable, Codable {
    let fileName: String
    let fileUrl: String     // Magnet/torrent URL
    let fileSize: Int64
    let nbSeeders: Int
    let nbLeechers: Int
    let siteUrl: String
    let descrLink: String
}

struct SearchPlugin: Identifiable, Codable {
    let name: String
    let version: String
    let url: String
    let enabled: Bool
    let fullName: String
    let supportedCategories: [String]
}
```

## API Integration

### Authentication
```swift
// Auto-connect on app launch
func autoConnect() async {
    serverURL = defaultServerURL
    username = defaultUsername
    password = defaultPassword
    await login()
}

// Login with cookie-based auth
func login() async {
    // POST /api/v2/auth/login
    // Stores cookie for subsequent requests
}
```

### Torrent Operations
```swift
// List torrents
func fetchTorrents() async -> [Torrent]

// Control
func pauseTorrent(hash: String) async
func resumeTorrent(hash: String) async
func deleteTorrent(hash: String, deleteFiles: Bool) async

// Bulk operations
func pauseAll() async
func resumeAll() async
func removeMissingFilesTorrents() async

// Add with options
func addTorrentWithOptions(
    url: String,
    savePath: String?,
    category: String?,
    sequentialDownload: Bool,
    firstLastPiecePriority: Bool,
    skipHashCheck: Bool,
    paused: Bool
) async -> Bool
```

### File Management
```swift
func getTorrentFiles(hash: String) async -> [TorrentFile]
func setFilePriority(hash: String, fileIds: [Int], priority: Int) async
```

### Search
```swift
func getSearchPlugins() async -> [SearchPlugin]
func searchTorrents(query: String, category: String) async -> [SearchResult]
```

## State Management

### Torrent States
- `downloading` - Active download
- `uploading` / `seeding` - Seeding
- `pausedDL` / `pausedUP` - Paused
- `queuedDL` / `queuedUP` - Queued
- `stalledDL` / `stalledUP` - Stalled
- `checkingDL` / `checkingUP` - Checking
- `allocating` - Allocating space
- `metaDL` - Downloading metadata
- `forcedDL` / `forcedUP` - Forced
- `missingFiles` - Files missing
- `error` - Error state

### Filter Logic
```swift
enum TorrentFilter {
    case all, downloading, seeding, paused, completed, active
    
    func matches(_ torrent: Torrent) -> Bool
}
```

## Configuration

### Default Server Settings
Located in `QBittorrentAPI.swift`:
```swift
private let defaultServerURL = "http://192.168.0.30:8080"
private let defaultUsername = "admin"
private let defaultPassword = "password"
```

### Save Paths
Hardcoded in `TorrentListView.swift` and `SearchView.swift`:
- Movies: `/srv/dev-disk-by-uuid-2f521503-8710-48ab-8e68-17875edf1865/Server/M`
- TV: `/srv/dev-disk-by-uuid-2f521503-8710-48ab-8e68-17875edf1865/Server/T`

### Network Permissions
`Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## UI Components

### Filter Tabs
- Horizontal scrollable chips
- Real-time count updates
- Color-coded selection

### Torrent Row
- Name, progress bar, state badge
- Download/upload speeds
- Swipe actions (pause/resume/delete)

### Search Interface
- Category filters
- Seeder/leecher display
- Direct add with options

## Development Workflow

### Building
```bash
# Open in Xcode
open qBittorrentRemote.xcodeproj

# Build: Cmd + B
# Run: Cmd + R
# Clean: Cmd + Shift + K
```

### Testing
- Use iOS Simulator for development
- Test on real device for network features
- Check Xcode console for API debug logs

### Debugging
API calls include console logging:
```
🔍 Starting search for: ubuntu
📡 Search start response: 200
✅ Search ID: 123456
📊 Status: Running, Total: 50
```

## API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v2/auth/login` | POST | Authentication |
| `/api/v2/torrents/info` | GET | List torrents |
| `/api/v2/torrents/add` | POST | Add torrent |
| `/api/v2/torrents/pause` | POST | Pause torrent(s) |
| `/api/v2/torrents/resume` | POST | Resume torrent(s) |
| `/api/v2/torrents/delete` | POST | Delete torrent(s) |
| `/api/v2/torrents/files` | GET | Get torrent files |
| `/api/v2/torrents/filePrio` | POST | Set file priority |
| `/api/v2/search/plugins` | GET | List search plugins |
| `/api/v2/search/start` | POST | Start search |
| `/api/v2/search/status` | GET | Check search status |
| `/api/v2/search/results` | GET | Get search results |
| `/api/v2/search/stop` | POST | Stop search |

## Common Tasks

### Adding a New Feature
1. Update data models if needed (`QBittorrentAPI.swift`)
2. Add API method (`QBittorrentAPI.swift`)
3. Create/update UI view
4. Test with real qBittorrent server

### Modifying Server Paths
Edit the button actions in:
- `TorrentListView.swift` (AddTorrentView)
- `SearchView.swift` (AddTorrentOptionsView)

### Changing Default Credentials
Update in `QBittorrentAPI.swift`:
```swift
private let defaultServerURL = "http://YOUR_IP:PORT"
private let defaultUsername = "YOUR_USERNAME"
private let defaultPassword = "YOUR_PASSWORD"
```

### Adding New Torrent States
1. Add case to `formattedState` computed property
2. Update `stateColor` for color coding
3. Update filter matching logic if needed

## Dependencies

- **SwiftUI** - UI framework
- **Foundation** - Networking, JSON
- **Combine** - Reactive state management (via @Published)

No external dependencies required.

## Performance Considerations

- Torrent list refreshes on pull-to-refresh
- Search polls status every 1 second
- File list loads on-demand
- Cookie persists in memory only (not saved)

## Security Notes

- HTTP only (no HTTPS validation)
- Credentials stored in memory
- Designed for local network use
- No keychain integration

For production:
- Implement HTTPS
- Add keychain storage
- Certificate pinning
- Input validation

## Troubleshooting

**Connection Issues**
- Check server URL format includes `http://`
- Verify port number
- Ensure Web UI is enabled in qBittorrent
- Check network connectivity

**Search Not Working**
- Install search plugins in qBittorrent Web UI
- Enable plugins in plugin manager
- Check console for search status logs

**Missing Files**
- Use "Remove Missing Files" bulk action
- Verify file paths match server paths
- Check file permissions on server

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with clear commits
4. Test thoroughly
5. Submit pull request

## License

MIT License - See LICENSE file for details
