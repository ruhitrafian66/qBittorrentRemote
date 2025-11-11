import SwiftUI

struct ContentView: View {
    @StateObject private var api = QBittorrentAPI()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                if api.isConnected {
                    TorrentListView(api: api)
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        
                        Text("Connecting...")
                            .font(.title2)
                        
                        Text("Connecting to qBittorrent server")
                            .foregroundColor(.secondary)
                        
                        if !api.errorMessage.isEmpty {
                            Text(api.errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Button("Retry") {
                                Task {
                                    await api.autoConnect()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Settings") {
                                showingSettings = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("qBittorrent")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(api: api)
            }
            .task {
                await api.autoConnect()
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var api: QBittorrentAPI
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isConnecting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Server") {
                    TextField("URL", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                
                Section("Authentication") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                }
                
                Section {
                    Button("Connect") {
                        isConnecting = true
                        api.configure(url: serverURL, username: username, password: password)
                        Task {
                            await api.login()
                            isConnecting = false
                            if api.isConnected {
                                dismiss()
                            }
                        }
                    }
                    .disabled(serverURL.isEmpty || isConnecting)
                    
                    if isConnecting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    
                    if !api.errorMessage.isEmpty {
                        Text(api.errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Example") {
                    Text("URL: http://192.168.1.100:8080")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                serverURL = api.serverURL.isEmpty ? "http://192.168.0.30:8080" : api.serverURL
                username = api.username.isEmpty ? "admin" : api.username
            }
        }
    }
}
