import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager
    @AppStorage("selectedProfileId") private var selectedProfileId: String?
    @State private var adminToken: String?
    @State private var adminPassword = ""
    @State private var showAdminLogin = false
    @State private var scanStatus: ScanStatusResponse?
    @State private var isScanning = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section("Profile") {
                    if let profileId = selectedProfileId, profileId != "guest" {
                        HStack {
                            Label("Active Profile", systemImage: "person.circle")
                            Spacer()
                            Text(profileId)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label("Guest Mode", systemImage: "person.circle.fill")
                    }

                    Button("Switch Profile") {
                        serverManager.logoutProfile()
                        selectedProfileId = nil
                    }
                }

                // Admin section
                Section("Admin") {
                    if let token = adminToken {
                        Button {
                            triggerScan(token: token)
                        } label: {
                            HStack {
                                Label(isScanning ? "Scanning..." : "Scan Libraries", systemImage: "arrow.clockwise")
                                if isScanning {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isScanning)

                        if let status = scanStatus {
                            if let progress = status.progress {
                                Text(progress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button("Unlock Admin") {
                            showAdminLogin = true
                        }
                    }
                }

                // Server section
                Section("Server") {
                    HStack {
                        Label("Server URL", systemImage: "server.rack")
                        Spacer()
                        Text(serverManager.serverURL?.absoluteString ?? "—")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Button("Disconnect", role: .destructive) {
                        serverManager.disconnect()
                        selectedProfileId = nil
                    }
                }

                // About section
                Section("About") {
                    HStack {
                        Label("OpenPanel", systemImage: "book.pages")
                        Spacer()
                        Text("iOS Client")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Admin Login", isPresented: $showAdminLogin) {
                SecureField("Password", text: $adminPassword)
                Button("Cancel", role: .cancel) { adminPassword = "" }
                Button("Unlock") { unlockAdmin() }
            }
        }
    }

    private func unlockAdmin() {
        guard let client = serverManager.apiClient else { return }
        Task {
            do {
                let token = try await client.adminUnlock(password: adminPassword)
                adminToken = token
                adminPassword = ""
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func triggerScan(token: String) {
        guard let client = serverManager.apiClient else { return }
        isScanning = true
        Task {
            do {
                try await client.triggerScan(adminToken: token)
                // Poll scan status
                try await Task.sleep(for: .seconds(1))
                scanStatus = try await client.scanStatus(adminToken: token)
                isScanning = scanStatus?.scanning ?? false
            } catch {
                self.error = error.localizedDescription
                isScanning = false
            }
        }
    }
}
