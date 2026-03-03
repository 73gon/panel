import SwiftUI

struct ServerConnectView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var urlText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo & title
            VStack(spacing: 12) {
                Image(systemName: "book.pages")
                    .font(.system(size: 56))
                    .foregroundStyle(.primary)

                Text("OpenPanel")
                    .font(.largeTitle.bold())

                Text("Connect to your server")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // URL input
            VStack(spacing: 16) {
                TextField("Server URL", text: $urlText, prompt: Text("http://192.168.1.100:6515"))
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit { connect() }

                Button(action: connect) {
                    if serverManager.isConnecting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(urlText.isEmpty || serverManager.isConnecting)

                if let error = serverManager.connectionError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .onAppear { isFocused = true }
    }

    private func connect() {
        Task {
            await serverManager.connect(to: urlText)
        }
    }
}
