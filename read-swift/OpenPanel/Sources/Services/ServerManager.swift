import Foundation
import SwiftUI

// MARK: - Server Manager

@MainActor
final class ServerManager: ObservableObject {
    @AppStorage("serverURL") private var savedURL: String = ""
    @AppStorage("deviceId") private var savedDeviceId: String = ""

    @Published var serverURL: URL?
    @Published var apiClient: APIClient?
    @Published var isConnecting = false
    @Published var connectionError: String?

    var deviceId: String {
        if savedDeviceId.isEmpty {
            savedDeviceId = UUID().uuidString.lowercased()
        }
        return savedDeviceId
    }

    init() {
        if let url = URL(string: savedURL), !savedURL.isEmpty {
            serverURL = url
            let token = UserDefaults.standard.string(forKey: "profileToken")
            apiClient = APIClient(baseURL: url, deviceId: deviceId, profileToken: token)
        }
    }

    func connect(to urlString: String) async {
        isConnecting = true
        connectionError = nil

        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "http://\(normalized)"
        }
        // Remove trailing slash
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        guard let url = URL(string: normalized) else {
            connectionError = "Invalid URL"
            isConnecting = false
            return
        }

        let client = APIClient(baseURL: url, deviceId: deviceId)

        do {
            let healthy = try await client.healthCheck()
            if healthy {
                savedURL = normalized
                serverURL = url
                apiClient = client
            } else {
                connectionError = "Server not responding"
            }
        } catch {
            connectionError = error.localizedDescription
        }

        isConnecting = false
    }

    func disconnect() {
        savedURL = ""
        serverURL = nil
        apiClient = nil
        UserDefaults.standard.removeObject(forKey: "profileToken")
        UserDefaults.standard.removeObject(forKey: "selectedProfileId")
    }

    func selectProfile(token: String, profileId: String) {
        UserDefaults.standard.set(token, forKey: "profileToken")
        UserDefaults.standard.set(profileId, forKey: "selectedProfileId")
        apiClient?.profileToken = token
    }

    func logoutProfile() {
        UserDefaults.standard.removeObject(forKey: "profileToken")
        UserDefaults.standard.removeObject(forKey: "selectedProfileId")
        apiClient?.profileToken = nil
    }
}
