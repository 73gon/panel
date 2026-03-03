import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var serverManager: ServerManager

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                LibraryView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}
