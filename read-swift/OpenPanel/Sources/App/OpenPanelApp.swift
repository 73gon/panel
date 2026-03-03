import SwiftUI

@main
struct OpenPanelApp: App {
    @StateObject private var serverManager = ServerManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(serverManager)
        }
    }
}
