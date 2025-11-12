# qBittorrent Remote iOS App

A native iOS app to remotely manage qBittorrent-nox-static over HTTP. Built with SwiftUI for iOS 15+.

## Features

### Core Functionality
-  Auto-connect with saved credentials
-  View all torrents with real-time progress
-  Download and upload speed monitoring
-  File size and progress tracking
-  Pull to refresh torrent list

### Torrent Management
-  Pause/Resume individual torrents
-  Pause/Resume all torrents
-  Delete torrents (with or without files)
-  Add torrents via URL or magnet link
-  Swipe actions for quick controls
-  **Selective file downloads** - Choose which files to download
-  **Torrent search** - Search and discover torrents using qBittorrent plugins

### Organization
- 🔍 Search torrents by name
- 🏷️ Filter tabs:
  - All torrents
  - Downloading
  - Seeding
  - Paused
  - Completed
  - Active (with speed > 0)

### Details
-  Detailed torrent information view
-  Color-coded states (downloading, seeding, paused, error)
-  Real-time speed and progress updates

## Screenshots

[Add screenshots here]

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.0+
- qBittorrent with Web UI enabled

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/ruhitrafian66/qBittorrentRemote.git
   cd qBittorrentRemote
   ```

2. Open `qBittorrentRemote.xcodeproj` in Xcode

3. Update credentials in `QBittorrentAPI.swift` (lines 8-10):
   ```swift
   private let defaultServerURL = "http://YOUR_SERVER_IP:8080"
   private let defaultUsername = "admin"
   private let defaultPassword = "your_password"
   ```

4. Build and run on your device or simulator

## Configuration

### Default Credentials
The app is configured to auto-connect with default credentials. You can change these in Settings or modify the defaults in `QBittorrentAPI.swift`.

### qBittorrent Server Setup
1. Enable Web UI in qBittorrent settings
2. Set a username and password
3. Note the port (default: 8080)
4. Ensure your iOS device can reach the server on your network

## Usage

### Adding Torrents

**Method 1: Direct URL/Magnet**
1. Tap the **+** button in the top right
2. Select "Add Torrent URL"
3. Paste a magnet link or torrent URL
4. Tap "Add Torrent"

**Method 2: Search**
1. Tap the **+** button in the top right
2. Select "Search Torrents"
3. Enter search keywords
4. Select category filter (optional)
5. Tap a result to add it directly

### Managing Torrents
- **Swipe left** on a torrent for quick actions (pause/resume/delete)
- **Tap** a torrent to view detailed information
- Use the **menu** (top left) for bulk actions
- **Manage Files**: Tap "Manage Files" in torrent details to:
  - View all files in the torrent
  - Select/deselect individual files for download
  - See download progress per file
  - Bulk select/deselect all files

### Filtering & Search
- Tap filter tabs at the top to filter by state
- Pull down to reveal the search bar
- Search and filters work together

## Technical Details

### Architecture
- **SwiftUI** for UI
- **Async/await** for network calls
- **ObservableObject** for state management
- **qBittorrent Web API v2** integration

### API Endpoints Used
- `/api/v2/auth/login` - Authentication
- `/api/v2/torrents/info` - List torrents
- `/api/v2/torrents/add` - Add torrent
- `/api/v2/torrents/pause` - Pause torrent(s)
- `/api/v2/torrents/resume` - Resume torrent(s)
- `/api/v2/torrents/delete` - Delete torrent(s)
- `/api/v2/torrents/files` - Get torrent files
- `/api/v2/torrents/filePrio` - Set file priority
- `/api/v2/search/plugins` - Get search plugins
- `/api/v2/search/start` - Start search
- `/api/v2/search/results` - Get search results
- `/api/v2/search/stop` - Stop search

## Security Notes

- The app allows arbitrary HTTP loads for local network connections
- Credentials are stored in memory only (not persisted)
- Designed for local network use
- For production use, consider implementing:
  - Keychain storage for credentials
  - HTTPS support
  - Certificate pinning

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - feel free to use this project for personal or commercial purposes.

## Acknowledgments

- Built for [qBittorrent](https://www.qbittorrent.org/)
- Uses qBittorrent Web API v2

## Support

If you encounter any issues or have questions, please open an issue on GitHub.
