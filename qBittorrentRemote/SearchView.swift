import SwiftUI

struct SearchView: View {
    @ObservedObject var api: QBittorrentAPI
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var plugins: [SearchPlugin] = []
    @State private var isSearching = false
    @State private var showPluginManager = false
    @State private var selectedCategory = "all"
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var hasSearched = false
    @Environment(\.dismiss) var dismiss
    
    let categories = ["all", "movies", "tv", "music", "games", "anime", "software", "books"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search torrents...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(
                                title: category.capitalized,
                                isSelected: selectedCategory == category
                            )
                            .onTapGesture {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Results
                if isSearching {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if hasSearched && searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No results found")
                            .foregroundColor(.secondary)
                        Text("Try different keywords or check if search plugins are installed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Check Plugins") {
                            showPluginManager = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasSearched {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Search for torrents")
                            .foregroundColor(.secondary)
                        Text("Enter keywords and press search")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(searchResults) { result in
                            SearchResultRow(result: result, api: api)
                        }
                    }
                }
            }
            .navigationTitle("Search Torrents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPluginManager = true
                    } label: {
                        Image(systemName: "puzzlepiece.extension")
                    }
                }
            }
            .sheet(isPresented: $showPluginManager) {
                PluginManagerView(api: api)
            }
            .alert("Search Info", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                plugins = await api.getSearchPlugins()
                if plugins.isEmpty {
                    errorMessage = "No search plugins found. Install plugins in qBittorrent Web UI under Tools > Search > Search plugins."
                    showError = true
                }
            }
        }
    }
    
    func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        searchResults = []
        Task {
            let results = await api.searchTorrents(query: searchQuery, category: selectedCategory)
            searchResults = results
            isSearching = false
            
            if results.isEmpty {
                print("⚠️ No results returned from search")
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    @ObservedObject var api: QBittorrentAPI
    @State private var isAdding = false
    @State private var showAddOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.fileName)
                .font(.subheadline)
                .lineLimit(2)
            
            HStack {
                Label("\(result.nbSeeders)", systemImage: "arrow.up.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Label("\(result.nbLeechers)", systemImage: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text(formatSize(result.fileSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button {
                    showAddOptions = true
                } label: {
                    if isAdding {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isAdding)
                
                if let url = URL(string: result.descrLink) {
                    Link(destination: url) {
                        Label("Details", systemImage: "info.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showAddOptions) {
            AddTorrentOptionsView(
                torrentURL: result.fileUrl,
                torrentName: result.fileName,
                api: api,
                isAdding: $isAdding
            )
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

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(uiColor: .systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

struct AddTorrentOptionsView: View {
    let torrentURL: String
    let torrentName: String
    @ObservedObject var api: QBittorrentAPI
    @Binding var isAdding: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var savePath: String = ""
    @State private var category: String = ""
    @State private var sequentialDownload = false
    @State private var firstLastPiecePriority = false
    @State private var skipHashCheck = false
    @State private var startPaused = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Torrent") {
                    Text(torrentName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section("Download Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Save Location")
                            .font(.subheadline)
                        
                        HStack(spacing: 12) {
                            Button {
                                savePath = "/srv/dev-disk-by-uuid-2f521503-8710-48ab-8e68-17875edf1865/Server/M"
                            } label: {
                                HStack {
                                    Image(systemName: "film")
                                    Text("Movies")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .tint(savePath.contains("/M") ? .blue : .gray)
                            
                            Button {
                                savePath = "/srv/dev-disk-by-uuid-2f521503-8710-48ab-8e68-17875edf1865/Server/T"
                            } label: {
                                HStack {
                                    Image(systemName: "tv")
                                    Text("TV")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .tint(savePath.contains("/T") ? .blue : .gray)
                        }
                        
                        if !savePath.isEmpty {
                            Text(savePath)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    HStack {
                        Text("Category")
                        Spacer()
                        TextField("None", text: $category)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Download Options") {
                    Toggle("Sequential Download", isOn: $sequentialDownload)
                    Toggle("First/Last Piece Priority", isOn: $firstLastPiecePriority)
                    Toggle("Skip Hash Check", isOn: $skipHashCheck)
                    Toggle("Start Paused", isOn: $startPaused)
                }
                
                Section {
                    Text("Sequential download is useful for media files that you want to preview while downloading.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("Add Torrent") {
                        isAdding = true
                        Task {
                            let success = await api.addTorrentWithOptions(
                                url: torrentURL,
                                savePath: savePath.isEmpty ? nil : savePath,
                                category: category.isEmpty ? nil : category,
                                sequentialDownload: sequentialDownload,
                                firstLastPiecePriority: firstLastPiecePriority,
                                skipHashCheck: skipHashCheck,
                                paused: startPaused
                            )
                            isAdding = false
                            if success {
                                await api.fetchTorrents()
                                dismiss()
                            }
                        }
                    }
                    .disabled(isAdding)
                    
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
            }
            .navigationTitle("Add Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PluginManagerView: View {
    @ObservedObject var api: QBittorrentAPI
    @State private var plugins: [SearchPlugin] = []
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading plugins...")
                } else if plugins.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No search plugins installed")
                            .foregroundColor(.secondary)
                        Text("Install plugins in qBittorrent Web UI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(plugins) { plugin in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(plugin.fullName)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Image(systemName: plugin.enabled ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(plugin.enabled ? .green : .gray)
                                }
                                
                                Text("Version: \(plugin.version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if !plugin.supportedCategories.isEmpty {
                                    Text("Categories: \(plugin.supportedCategories.joined(separator: ", "))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Search Plugins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                plugins = await api.getSearchPlugins()
                isLoading = false
            }
        }
    }
}
