import SwiftUI

struct RootView: View {
    @EnvironmentObject var serverManager: ServerManager
    @AppStorage("selectedProfileId") private var selectedProfileId: String?

    var body: some View {
        Group {
            if serverManager.serverURL == nil {
                ServerConnectView()
            } else if selectedProfileId == nil {
                ProfilePickerView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: serverManager.serverURL)
        .animation(.easeInOut(duration: 0.3), value: selectedProfileId)
    }
}
