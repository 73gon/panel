import SwiftUI

struct ProfilePickerView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var profiles: [Profile] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showPinEntry: Profile?
    @State private var pin = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Who's reading?")
                        .font(.title2.bold())
                        .padding(.top, 32)

                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 20)
                        ], spacing: 20) {
                            ForEach(profiles) { profile in
                                ProfileCard(profile: profile) {
                                    if profile.hasPin {
                                        showPinEntry = profile
                                    } else {
                                        selectProfile(profile, pin: nil)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Disconnect") {
                        serverManager.disconnect()
                    }
                    .foregroundStyle(.red)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guest") {
                        // Skip profile selection - use device-only tracking
                        UserDefaults.standard.set("guest", forKey: "selectedProfileId")
                    }
                }
            }
            .alert("Enter PIN", isPresented: .init(
                get: { showPinEntry != nil },
                set: { if !$0 { showPinEntry = nil; pin = "" } }
            )) {
                SecureField("PIN", text: $pin)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) {
                    showPinEntry = nil
                    pin = ""
                }
                Button("OK") {
                    if let profile = showPinEntry {
                        selectProfile(profile, pin: pin)
                    }
                }
            }
            .task { await loadProfiles() }
        }
    }

    private func loadProfiles() async {
        guard let client = serverManager.apiClient else { return }
        isLoading = true
        do {
            profiles = try await client.fetchProfiles()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func selectProfile(_ profile: Profile, pin: String?) {
        guard let client = serverManager.apiClient else { return }
        Task {
            do {
                let response = try await client.selectProfile(id: profile.id, pin: pin)
                serverManager.selectProfile(token: response.token, profileId: profile.id)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Profile Card

private struct ProfileCard: View {
    let profile: Profile
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                Circle()
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Text(profile.name.prefix(1).uppercased())
                            .font(.title.bold())
                            .foregroundStyle(.primary)
                    }

                Text(profile.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if profile.hasPin {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
