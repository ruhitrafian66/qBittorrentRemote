import SwiftUI

struct SearchView: View {
    @ObservedObject var api: QBittorrentAPI
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var plugins: [SearchPlugin] = []
    @State private var isSearching = false
    @State private var showPluginManager = false
    @State private var selectedCategory = "all"
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
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No results found")
                            .foregroundColor(.secondary)
                        Text("Try different keywords")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty {
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
            .task {
                plugins = await api.getSearchPlugins()
            }
        }
    }
    
    func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        Task {
            searchResults = await api.searchTorrents(query: searchQuery, category: selectedCategory)
            isSearching = false
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    @ObservedObject var api: QBittorrentAPI
    @State private var isAdding = false
    
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
                    isAdding = true
                    Task {
                        let success = await api.addTorrentURL(result.fileUrl)
                        isAdding = false
                        if success {
                            await api.fetchTorrents()
                        }
                    }
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
