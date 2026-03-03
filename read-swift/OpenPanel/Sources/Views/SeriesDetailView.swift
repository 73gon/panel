import SwiftUI

struct SeriesDetailView: View {
    @EnvironmentObject var serverManager: ServerManager
    let series: Series

    @State private var books: [Book] = []
    @State private var progress: [String: ReadingProgress] = [:]
    @State private var isLoading = true
    @State private var error: String?
    @State private var sortAscending = true

    private var sortedBooks: [Book] {
        sortAscending
            ? books.sorted { $0.sortOrder < $1.sortOrder }
            : books.sorted { $0.sortOrder > $1.sortOrder }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if let error {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    // Series info header
                    seriesHeader

                    Divider()

                    // Sort & count bar
                    HStack {
                        Text("\(books.count) \(series.bookType == "volume" ? "volumes" : "chapters")")
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        Button {
                            withAnimation { sortAscending.toggle() }
                        } label: {
                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                .font(.subheadline)
                        }
                    }

                    // Book grid
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(sortedBooks) { book in
                            NavigationLink {
                                ReaderView(bookId: book.id, seriesId: series.id, books: books)
                            } label: {
                                BookGridCard(book: book, progress: progress[book.id])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBooks() }
    }

    // MARK: - Series Header

    private var seriesHeader: some View {
        HStack(spacing: 16) {
            // Cover
            ZStack {
                CachedAsyncImage(url: serverManager.apiClient?.seriesThumbnailURL(seriesId: series.id)) {
                    Rectangle().fill(.secondary.opacity(0.1))
                }
                .scaledToFill()
                .blur(radius: 20)
                .brightness(-0.2)
                .clipped()

                CachedAsyncImage(url: serverManager.apiClient?.seriesThumbnailURL(seriesId: series.id)) {
                    Image(systemName: "book.closed")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .scaledToFit()
            }
            .frame(width: 120)
            .aspectRatio(3/4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text(series.name)
                    .font(.title3.bold())

                if let year = series.year {
                    Label("\(year)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(series.bookCount) \(series.bookType == "volume" ? "volumes" : "chapters")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Continue reading button
                if let nextBook = findNextBook() {
                    NavigationLink {
                        ReaderView(bookId: nextBook.id, seriesId: series.id, books: books)
                    } label: {
                        Label("Continue Reading", systemImage: "book")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadBooks() async {
        guard let client = serverManager.apiClient else { return }
        isLoading = true
        do {
            let resp = try await client.fetchBooks(seriesId: series.id)
            books = resp.books

            let ids = books.map(\.id)
            progress = try await client.fetchBatchProgress(bookIds: ids)
            error = nil

            // Prefetch thumbnails
            if let client = serverManager.apiClient {
                let urls = books.map { client.thumbnailURL(bookId: $0.id) }
                await ImageCache.shared.prefetch(urls: urls)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func findNextBook() -> Book? {
        let sorted = books.sorted { $0.sortOrder < $1.sortOrder }
        // Find first non-completed book
        for book in sorted {
            if let prog = progress[book.id] {
                if !prog.isCompleted { return book }
            } else {
                return book
            }
        }
        return sorted.first
    }
}

// MARK: - Book Grid Card

struct BookGridCard: View {
    @EnvironmentObject var serverManager: ServerManager
    let book: Book
    let progress: ReadingProgress?

    private var pct: Int {
        guard let progress else { return 0 }
        return Int((Double(progress.page) / Double(book.pageCount)) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Cover
            ZStack(alignment: .bottom) {
                ZStack {
                    CachedAsyncImage(url: serverManager.apiClient?.thumbnailURL(bookId: book.id)) {
                        Rectangle().fill(.secondary.opacity(0.1))
                    }
                    .scaledToFill()
                    .blur(radius: 20)
                    .brightness(-0.2)
                    .clipped()

                    CachedAsyncImage(url: serverManager.apiClient?.thumbnailURL(bookId: book.id)) {
                        Image(systemName: "book.pages")
                            .foregroundStyle(.secondary)
                    }
                    .scaledToFit()
                }
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Progress bar
                if pct > 0 {
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(progress?.isCompleted == true ? .green : .accentColor)
                                .frame(width: geo.size.width * CGFloat(pct) / 100, height: 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Title
            Text(book.title)
                .font(.caption2.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(.primary)

            HStack(spacing: 2) {
                Text("\(book.pageCount)p")
                if let progress, progress.isCompleted {
                    Text("· Done")
                } else if pct > 0 {
                    Text("· \(pct)%")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
