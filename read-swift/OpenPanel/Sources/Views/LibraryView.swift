import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var libraries: [Library] = []
    @State private var allSeries: [Series] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""

    private var filteredSeries: [Series] {
        if searchText.isEmpty { return allSeries }
        return allSeries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    VStack {
                        ProgressView()
                            .padding(.top, 60)
                    }
                } else if let error {
                    ContentUnavailableView(
                        "Error Loading Library",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if allSeries.isEmpty {
                    ContentUnavailableView(
                        "No Series Found",
                        systemImage: "book.closed",
                        description: Text("Add a library in the admin panel and scan for books.")
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredSeries) { series in
                            NavigationLink(value: series) {
                                SeriesGridCard(series: series)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search series")
            .refreshable { await loadData() }
            .navigationDestination(for: Series.self) { series in
                SeriesDetailView(series: series)
            }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        guard let client = serverManager.apiClient else { return }
        isLoading = true
        do {
            let resp = try await client.fetchAllSeries(page: 1, perPage: 500)
            allSeries = resp.series
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Series Grid Card

struct SeriesGridCard: View {
    @EnvironmentObject var serverManager: ServerManager
    let series: Series

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover with blurred background
            ZStack {
                CachedAsyncImage(url: serverManager.apiClient?.seriesThumbnailURL(seriesId: series.id)) {
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                }
                .scaledToFill()
                .blur(radius: 20)
                .brightness(-0.2)
                .clipped()

                CachedAsyncImage(url: serverManager.apiClient?.seriesThumbnailURL(seriesId: series.id)) {
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                .scaledToFit()
            }
            .aspectRatio(3/4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Title
            Text(series.name)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text("\(series.bookCount) \(series.bookType == "volume" ? "volumes" : "chapters")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
