import SwiftUI

enum TorrentFilter: String, CaseIterable {
    case all = "All"
    case downloading = "Downloading"
    case seeding = "Seeding"
    case paused = "Paused"
    case completed = "Completed"
    case active = "Active"
    
    func matches(_ torrent: Torrent) -> Bool {
        let state = torrent.state.lowercased()
        switch self {
        case .all:
            return true
        case .downloading:
            return state.contains("downloading") || state.contains("stalledDL")
        case .seeding:
            return state.contains("uploading") || state.contains("seeding") || state.contains("stalledUP")
        case .paused:
            return state.contains("paused")
        case .completed:
            return torrent.progress >= 100
        case .active:
            return torrent.dlspeed > 0 || torrent.upspeed > 0
        }
    }
}

struct TorrentListView: View {
    @ObservedObject var api: QBittorrentAPI
    @State private var showingAddTorrent = false
    @State private var selectedTorrent: Torrent?
    @State private var selectedFilter: TorrentFilter = .all
    @State private var searchText = ""
    
    var filteredTorrents: [Torrent] {
        api.torrents.filter { torrent in
            let matchesFilter = selectedFilter.matches(torrent)
            let matchesSearch = searchText.isEmpty || torrent.name.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TorrentFilter.allCases, id: \.self) { filter in
                        FilterTab(
                            title: filter.rawValue,
                            count: api.torrents.filter { filter.matches($0) }.count,
                            isSelected: selectedFilter == filter
                        )
                        .onTapGesture {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemBackground))
            
            Divider()
            
            // Torrent list
            List {
                ForEach(filteredTorrents) { torrent in
                    TorrentRow(torrent: torrent)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTorrent = torrent
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await api.deleteTorrent(hash: torrent.hash)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            if torrent.state.lowercased().contains("paused") {
                                Button {
                                    Task {
                                        await api.resumeTorrent(hash: torrent.hash)
                                    }
                                } label: {
                                    Label("Resume", systemImage: "play.fill")
                                }
                                .tint(.green)
                            } else {
                                Button {
                                    Task {
                                        await api.pauseTorrent(hash: torrent.hash)
                                    }
                                } label: {
                                    Label("Pause", systemImage: "pause.fill")
                                }
                                .tint(.orange)
                            }
                        }
                }
                
                if filteredTorrents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(searchText.isEmpty ? "No torrents" : "No results")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .searchable(text: $searchText, prompt: "Search torrents")
            .refreshable {
                await api.fetchTorrents()
            }
            .task {
                await api.fetchTorrents()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            Task { await api.pauseAll() }
                        } label: {
                            Label("Pause All", systemImage: "pause.circle")
                        }
                        
                        Button {
                            Task { await api.resumeAll() }
                        } label: {
                            Label("Resume All", systemImage: "play.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddTorrent = true
                        } label: {
                            Label("Add Torrent URL", systemImage: "link")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTorrent) {
                AddTorrentView(api: api)
            }
            .sheet(item: $selectedTorrent) { torrent in
                TorrentDetailView(torrent: torrent, api: api)
            }
        }
    }
    
    struct FilterTab: View {
        let title: String
        let count: Int
        let isSelected: Bool
        
        var body: some View {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
    }
    
    struct TorrentRow: View {
        let torrent: Torrent
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(torrent.name)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Label("\(torrent.progress, specifier: "%.1f")%", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(torrent.state)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(stateColor.opacity(0.2))
                        .foregroundColor(stateColor)
                        .cornerRadius(4)
                }
                
                ProgressView(value: torrent.progress, total: 100)
                    .tint(stateColor)
                
                HStack {
                    Label(formatSpeed(torrent.dlspeed), systemImage: "arrow.down")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Label(formatSpeed(torrent.upspeed), systemImage: "arrow.up")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text(formatSize(torrent.size))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        
        var stateColor: Color {
            switch torrent.state.lowercased() {
            case "downloading": return .blue
            case "uploading", "seeding": return .green
            case "paused", "pausedDL", "pausedUP": return .orange
            case "error": return .red
            default: return .gray
            }
        }
        
        func formatSpeed(_ speed: Int64) -> String {
            let speedDouble = Double(speed)
            if speedDouble < 1024 {
                return "\(Int(speedDouble)) B/s"
            } else if speedDouble < 1024 * 1024 {
                return String(format: "%.1f KB/s", speedDouble / 1024)
            } else {
                return String(format: "%.1f MB/s", speedDouble / (1024 * 1024))
            }
        }
        
        func formatSize(_ size: Int64) -> String {
            let sizeDouble = Double(size)
            if sizeDouble < 1024 * 1024 {
                return String(format: "%.1f KB", sizeDouble / 1024)
            } else if sizeDouble < 1024 * 1024 * 1024 {
                return String(format: "%.1f MB", sizeDouble / (1024 * 1024))
            } else {
                return String(format: "%.2f GB", sizeDouble / (1024 * 1024 * 1024))
            }
        }
    }
    
    struct AddTorrentView: View {
        @ObservedObject var api: QBittorrentAPI
        @Environment(\.dismiss) var dismiss
        @State private var torrentURL: String = ""
        @State private var isAdding = false
        @State private var showError = false
        @State private var errorMessage = ""
        
        var body: some View {
            NavigationView {
                Form {
                    Section {
                        TextEditor(text: $torrentURL)
                            .frame(minHeight: 120)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Torrent URL or Magnet Link")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Paste a magnet link or torrent URL")
                            Text("Example: magnet:?xt=urn:btih:...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section {
                        Button("Add Torrent") {
                            isAdding = true
                            Task {
                                let success = await api.addTorrentURL(torrentURL)
                                isAdding = false
                                if success {
                                    await api.fetchTorrents()
                                    dismiss()
                                } else {
                                    errorMessage = "Failed to add torrent. Check the URL/magnet link."
                                    showError = true
                                }
                            }
                        }
                        .disabled(torrentURL.isEmpty || isAdding)
                        
                        if isAdding {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text("Adding torrent...")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    
                    Section("Quick Actions") {
                        Button {
                            if let clipboardString = UIPasteboard.general.string {
                                torrentURL = clipboardString
                            }
                        } label: {
                            Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        }
                        
                        Button(role: .destructive) {
                            torrentURL = ""
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .disabled(torrentURL.isEmpty)
                    }
                }
                .navigationTitle("Add Torrent")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
            }
        }
    }
    
    struct TorrentDetailView: View {
        let torrent: Torrent
        @ObservedObject var api: QBittorrentAPI
        @Environment(\.dismiss) var dismiss
        @State private var showDeleteConfirm = false
        
        var body: some View {
            NavigationView {
                List {
                    Section("Information") {
                        DetailRow(label: "Name", value: torrent.name)
                        DetailRow(label: "State", value: torrent.state)
                        DetailRow(label: "Progress", value: String(format: "%.2f%%", torrent.progress))
                        DetailRow(label: "Size", value: formatSize(torrent.size))
                        DetailRow(label: "Download Speed", value: formatSpeed(torrent.dlspeed))
                        DetailRow(label: "Upload Speed", value: formatSpeed(torrent.upspeed))
                        DetailRow(label: "Hash", value: torrent.hash)
                            .font(.caption)
                    }
                    
                    Section("Actions") {
                        if torrent.state.lowercased().contains("paused") {
                            Button {
                                Task {
                                    await api.resumeTorrent(hash: torrent.hash)
                                    dismiss()
                                }
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                        } else {
                            Button {
                                Task {
                                    await api.pauseTorrent(hash: torrent.hash)
                                    dismiss()
                                }
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                        }
                        
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Torrent", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle("Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .confirmationDialog("Delete Torrent", isPresented: $showDeleteConfirm) {
                    Button("Delete Torrent Only", role: .destructive) {
                        Task {
                            await api.deleteTorrent(hash: torrent.hash, deleteFiles: false)
                            dismiss()
                        }
                    }
                    Button("Delete Torrent + Files", role: .destructive) {
                        Task {
                            await api.deleteTorrent(hash: torrent.hash, deleteFiles: true)
                            dismiss()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Choose how to delete this torrent")
                }
            }
        }
        
        func formatSpeed(_ speed: Int64) -> String {
            let speedDouble = Double(speed)
            if speedDouble < 1024 {
                return "\(Int(speedDouble)) B/s"
            } else if speedDouble < 1024 * 1024 {
                return String(format: "%.1f KB/s", speedDouble / 1024)
            } else {
                return String(format: "%.1f MB/s", speedDouble / (1024 * 1024))
            }
        }
        
        func formatSize(_ size: Int64) -> String {
            let sizeDouble = Double(size)
            if sizeDouble < 1024 * 1024 {
                return String(format: "%.1f KB", sizeDouble / 1024)
            } else if sizeDouble < 1024 * 1024 * 1024 {
                return String(format: "%.1f MB", sizeDouble / (1024 * 1024))
            } else {
                return String(format: "%.2f GB", sizeDouble / (1024 * 1024 * 1024))
            }
        }
    }
    
    struct DetailRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
