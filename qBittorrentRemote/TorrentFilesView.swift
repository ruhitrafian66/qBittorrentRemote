import SwiftUI

struct TorrentFilesView: View {
    let torrentHash: String
    @ObservedObject var api: QBittorrentAPI
    @State private var files: [TorrentFile] = []
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading files...")
                } else if files.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No files found")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(files) { file in
                            FileRow(file: file, torrentHash: torrentHash, api: api)
                        }
                    }
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await api.setFilePriority(hash: torrentHash, fileIds: files.map { $0.index }, priority: 1)
                                await loadFiles()
                            }
                        } label: {
                            Label("Download All", systemImage: "arrow.down.circle")
                        }
                        
                        Button {
                            Task {
                                await api.setFilePriority(hash: torrentHash, fileIds: files.map { $0.index }, priority: 0)
                                await loadFiles()
                            }
                        } label: {
                            Label("Skip All", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await loadFiles()
            }
        }
    }
    
    func loadFiles() async {
        isLoading = true
        files = await api.getTorrentFiles(hash: torrentHash)
        isLoading = false
    }
}

struct FileRow: View {
    let file: TorrentFile
    let torrentHash: String
    @ObservedObject var api: QBittorrentAPI
    
    var isDownloading: Bool {
        file.priority > 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isDownloading ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isDownloading ? .green : .gray)
                
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            
            HStack {
                Text(formatSize(file.size))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isDownloading {
                    Text("\(file.progress, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if isDownloading {
                ProgressView(value: file.progress, total: 100)
                    .tint(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                let newPriority = isDownloading ? 0 : 1
                await api.setFilePriority(hash: torrentHash, fileIds: [file.index], priority: newPriority)
            }
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
